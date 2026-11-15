# Public key registry: the single source for SSH and age public keys.
# Plaintext on purpose; nothing here is secret. Host keys live in hosts.nix.
{
  humans.zen = {
    # Nitrokey 3 resident keys; nk2 is the backup token.
    nk1 = {
      ssh = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILRJcwGCjNBL5Ro/0t7WqXdbGAtWy7XjgS07VTWpxl9KAAAAD3NzaDpudWxsaXR5c3Bhbg== nk1";
      age = "age1fido2-hmac1qqp2jzcryeq6p4qgsg479d3r6vw08tdmet747ufsmyypz7dcfzux2tqpw42hjdl08qeppn67mmctfk73zlxzs2halxkwyn7y6wx9xdp7yd76xqzc0ntk2admz5u8lvyqssq9547000k6rucph839aa00gqjazyahgjhzfxk99daxjtxtx9tyw67pvwhfa2vpy4eq5pxydacaqjxscnvfcgrkth4ps8z563t3z090lt36vr0amrsy9p6f6w32kfm2qppc84kcpgnxqcwd7mg0a3lv5z0f04c2ssq4kyprgzrphad5uxjpf8hpq9xg4gqsgtev2rykt805q8cz2qlcfwm44dl8873l7su0ywgsw64ql9hu87";
    };
    nk2 = {
      ssh = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICxZgzMRPcCSutrmKD3vZSBAuT6lgzHbxxHscOuf1a2dAAAAD3NzaDpudWxsaXR5c3Bhbg== nk2";
      age = "age1fido2-hmac1qqpw4w2vh6zv8vwxeq99rdvrerfxmtn32calh5gsykjr0ptypq0u6ncptjdtt25tefw3zsf26pps5a3ue0gwx50nrfhay9q7zesjeue9mfc2xqzc02aun7tezm9c2ze5shxqnrmuykzaz5hp87sfct6h8rn7sz233733wa4zhp5u9cfam8vnqf3wg4uph97tndpaun3u459mc55m9f2y6udcqup9rajvaz2wzpgcm344tkc2aeztwzx4gdswk5wkat3mfu6eyhrf3z6gxulm6h6pv4pagvwp837emvg4rsycg2c9pe506q2vamq08jp6s0z535g34l3sy59swm5yrtufds7yzeecpqm5cst82hfgyd";
    };
    # Offline emergency key, age only.
    recovery.age = "age1ye3hvd0gvus60dc0uu0thy8h5nkw4lvcn53uv2fsp7szksgvfexs6st2qj";
  };
}
