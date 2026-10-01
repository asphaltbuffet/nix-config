# Vivaldi Browser policies for every account on the host. The package itself
# is installed per login by home/modules/vivaldi.
#
# Vivaldi reads /etc/vivaldi/policies (verified from the 8.2 binary) — not
# /etc/chromium, so nixpkgs' programs.chromium module can't target it.
# No ad-blocking extension: Manifest V2 (uBlock Origin) is gone from Chromium,
# so blocking is left to Vivaldi's built-in blocker, which has no policy.
_: let
  webStore = id: "${id};https://clients2.google.com/service/update2/crx";
in {
  environment.etc = {
    "vivaldi/policies/managed/default.json".text = builtins.toJSON {
      ExtensionInstallForcelist = map webStore [
        "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
        "cdglnehniifkbagbbombnjghhcihifij" # Kagi Search
      ];
      DefaultBrowserSettingEnabled = false;
      MetricsReportingEnabled = false;
      # 1Password owns passwords and cards.
      PasswordManagerEnabled = false;
      AutofillCreditCardEnabled = false;
    };

    # Recommended, not managed: a default each person may change.
    "vivaldi/policies/recommended/default.json".text = builtins.toJSON {
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "Kagi";
      DefaultSearchProviderKeyword = "kagi";
      DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    };
  };
}
