{...}: {
  programs.mise = {
    enable = true;

    enableZshIntegration = true;

    globalConfig = {
      settings = {
        color_theme = "charm";
        idiomatic_version_file_enable_tools = ["python"];
        experimental = true;
      };
    };
  };
}
