_: {
  # ===============================================================
  #       KERNEL HARDENING
  # ===============================================================
  boot.kernel.sysctl = {
    # Kernel info leaks
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;

    # Attack surface
    "net.core.bpf_jit_harden" = 2;
    "kernel.kexec_load_disabled" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "vm.unprivileged_userfaultfd" = 0;
    "dev.tty.ldisc_autoload" = 0;

    # Filesystem
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;

    # Network: ignore ICMP redirects and source routing
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
  };
}
