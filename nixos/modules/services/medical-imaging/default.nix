{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.host.services.medicalImaging;

  orthancPort = 8042;
  ohifPort = 3000;
  monaiPort = 8000;
  tlsDir = "/var/lib/medimg-tls";

  pseudonymise = pkgs.writers.writePython3Bin "dicom-pseudonymise" {
    libraries = [ pkgs.python3Packages.pydicom ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./pseudonymise.py);

  # OHIF reads DICOMweb through the same origin (nginx), so paths are relative.
  ohifConfig = pkgs.writeText "app-config.js" ''
    window.config = {
      routerBasename: '/',
      showStudyList: true,
      extensions: [],
      modes: [],
      defaultDataSourceName: 'orthanc',
      dataSources: [
        {
          namespace: '@ohif/extension-default.dataSourcesModule.dicomweb',
          sourceName: 'orthanc',
          configuration: {
            friendlyName: 'Orthanc (satalite)',
            name: 'orthanc',
            wadoUriRoot: '/dicom-web',
            qidoRoot: '/dicom-web',
            wadoRoot: '/dicom-web',
            qidoSupportsIncludeField: false,
            imageRendering: 'wadors',
            thumbnailRendering: 'wadors',
            enableStudyLazyLoad: true,
            supportsFuzzyMatching: false,
            supportsWildcard: true,
            dicomUploadEnabled: true,
            omitQuotationForMultipartRequest: true,
            bulkDataURI: { enabled: true, relativeResolution: 'studies' },
          },
        },
      ],
    };
  '';

  monaiStart = pkgs.writeShellScript "monailabel-start" ''
    set -eu
    [ -d /data/apps/radiology ] || monailabel apps --download --name radiology --output /data/apps
    exec monailabel start_server \
      --app /data/apps/radiology \
      --studies http://127.0.0.1:${toString orthancPort}/dicom-web \
      --conf models segmentation \
      --host 127.0.0.1 --port ${toString monaiPort}
  '';

  auth = {
    basicAuthFile = config.sops.secrets.medimg-htpasswd.path;
    sslCertificate = "${tlsDir}/cert.pem";
    sslCertificateKey = "${tlsDir}/key.pem";
  };
in
{
  options.host.services.medicalImaging.enable =
    lib.mkEnableOption "medical image archive, annotation (OHIF, MONAI Label) and pseudonymisation";

  config = lib.mkIf cfg.enable {
    host.partition.persist.extraDirectories = [
      "/var/lib/orthanc"
      "/var/lib/monailabel"
      tlsDir
    ];

    sops.secrets = {
      # htpasswd lines for nginx basic auth (OHIF, Orthanc, MONAI Label).
      medimg-htpasswd = {
        sopsFile = ../../../hosts/${config.host.settings.name}/secrets.sops.yaml;
        owner = "nginx";
      };
      # >= 32 random bytes; losing it breaks pseudonym continuity.
      pseudonym-key = {
        sopsFile = ../../../hosts/${config.host.settings.name}/secrets.sops.yaml;
        group = "medimg";
        mode = "0440";
      };
    };

    users.groups.medimg = { };
    users.users.${config.host.users.primary}.extraGroups = [ "medimg" ];

    environment.systemPackages = [
      pseudonymise
      pkgs.dcmtk
      pkgs.dcm2niix
    ];

    # ===============================================================
    #       ORTHANC (DICOM archive, DICOMweb)
    # ===============================================================
    services.orthanc = {
      enable = true;
      settings = {
        Name = config.host.settings.name;
        HttpPort = orthancPort;
        # Localhost only: nginx terminates TLS and auth.
        RemoteAccessAllowed = false;
        AuthenticationEnabled = false;
        DicomAet = lib.toUpper config.host.settings.name;
        DicomPort = 4242;
        IndexDirectory = "/var/lib/orthanc";
        StorageDirectory = "/var/lib/orthanc";
        Plugins = [ "${pkgs.orthanc-plugin-dicomweb}/share/orthanc/plugins" ];
        DicomWeb = {
          Enable = true;
          Root = "/dicom-web/";
          EnableWado = true;
          WadoRoot = "/wado";
          StudiesMetadata = "Full";
          SeriesMetadata = "Full";
        };
      };
    };

    # Static user so the state dir is a plain, persistable /var/lib/orthanc.
    users.users.orthanc = {
      isSystemUser = true;
      group = "orthanc";
    };
    users.groups.orthanc = { };
    systemd.services.orthanc.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "orthanc";
      Group = "orthanc";
    };

    # ===============================================================
    #       OHIF VIEWER + MONAI LABEL (containers, host network)
    # ===============================================================
    virtualisation.oci-containers.containers = {
      ohif = {
        image = "ohif/app:v3.13.8";
        environment.PORT = toString ohifPort;
        volumes = [ "${ohifConfig}:/usr/share/nginx/html/app-config.js:ro" ];
        extraOptions = [ "--network=host" ];
      };
      monailabel = {
        image = "projectmonai/monailabel:0.8.5";
        entrypoint = "/bin/sh";
        cmd = [ "/start.sh" ];
        # Model/app downloads go through the corporate proxy.
        environment = config.networking.proxy.envVars;
        volumes = [
          "/var/lib/monailabel:/data"
          "${monaiStart}:/start.sh:ro"
        ];
        extraOptions = [
          "--network=host"
          "--device=nvidia.com/gpu=all"
          "--shm-size=8g"
        ];
      };
    };

    # ===============================================================
    #       NGINX (TLS + basic auth in front of everything)
    # ===============================================================
    # Self-signed until a corporate cert is dropped into ${tlsDir}.
    systemd.services.medimg-tls = {
      wantedBy = [ "nginx.service" ];
      before = [ "nginx.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        [ -s ${tlsDir}/cert.pem ] && exit 0
        install -d -m 0750 -o root -g nginx ${tlsDir}
        ${lib.getExe pkgs.openssl} req -x509 -newkey rsa:4096 -nodes -days 825 \
          -subj "/CN=${config.networking.hostName}" \
          -keyout ${tlsDir}/key.pem -out ${tlsDir}/cert.pem
        chgrp nginx ${tlsDir}/key.pem ${tlsDir}/cert.pem
        chmod 0640 ${tlsDir}/key.pem
      '';
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;
      clientMaxBodySize = "4G";
      virtualHosts = {
        viewer = auth // {
          default = true;
          forceSSL = true;
          locations = {
            "/".proxyPass = "http://127.0.0.1:${toString ohifPort}";
            "/orthanc/".proxyPass = "http://127.0.0.1:${toString orthancPort}/";
            "/dicom-web/".proxyPass = "http://127.0.0.1:${toString orthancPort}/dicom-web/";
          };
        };
        monailabel = auth // {
          onlySSL = true;
          listen = [
            {
              addr = "0.0.0.0";
              port = 8443;
              ssl = true;
            }
          ];
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString monaiPort}";
            proxyWebsockets = true;
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
      8443
    ];
  };
}
