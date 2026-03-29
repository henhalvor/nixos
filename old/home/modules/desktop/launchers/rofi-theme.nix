{
  config,
  ...
}: let
  colors = config.lib.stylix.colors;
in {
  home.file = {
    ".config/rofi/theme.rasi".text = ''
      @theme "~/.config/rofi/themes/glass.rasi"
    '';

    ".config/rofi/themes/glass.rasi".text = ''
      * {
          font: "${config.stylix.fonts.monospace.name} ${toString config.stylix.fonts.sizes.applications}";
      }

      window {
          background-color: rgba(${colors.base00-rgb-r}, ${colors.base00-rgb-g}, ${colors.base00-rgb-b}, 0.5);
          border: 1px;
          border-color: #${colors.base03};
          border-radius: 10px;
          padding: 10px;
          width: 550px;
          location: center;
          anchor: center;
          x-offset: 0;
          y-offset: 0;
          transparency: "real";
      }

      mainbox {
          enabled: true;
          spacing: 0px;
          padding: 0px;
          orientation: vertical;
          children: [ inputbar, listview ];
          background-color: transparent;
      }

      inputbar {
          enabled: true;
          spacing: 0px;
          padding: 8px 10px;
          margin: 0px;
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.05);
          border: 0 0 1px 0;
          border-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.15);
          border-radius: 10px;
          children: [ entry ];
      }

      prompt {
          enabled: false;
      }

      entry {
          enabled: true;
          background-color: transparent;
          text-color: #${colors.base05};
          placeholder: "";
          placeholder-color: #${colors.base05};
          expand: true;
          cursor: text;
      }

      listview {
          background-color: transparent;
          border: 0px;
          padding: 0px;
          margin: 0px;
          cycle: true;
          layout: vertical;
          spacing: 0px;
          scrollbar: false;
          columns: 1;
          dynamic: true;
          lines: 8;
          fixed-height: true;
      }

      element {
          enabled: true;
          padding: 6px 8px;
          margin: 0px;
          background-color: transparent;
          text-color: #${colors.base05};
          border: 0px;
          border-radius: 10px;
          orientation: horizontal;
          children: [ element-icon, element-text ];
      }

      element-icon {
          enabled: true;
          background-color: transparent;
          size: 1.2em;
          margin: 0px 10px 0px 0px;
      }

      element-text {
          background-color: transparent;
          text-color: inherit;
          highlight: none;
          expand: true;
          vertical-align: 0.5;
          format: "{text}";
      }

      element normal.normal {
          background-color: transparent;
          text-color: #${colors.base05};
      }

      element normal.active {
          background-color: transparent;
          text-color: #${colors.base0B};
      }

      element normal.urgent {
          background-color: transparent;
          text-color: #${colors.base08};
      }

      element selected.normal {
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.1);
          text-color: #${colors.base0D};
      }

      element selected.active {
          background-color: rgba(${colors.base05-rgb-r}, ${colors.base05-rgb-g}, ${colors.base05-rgb-b}, 0.1);
          text-color: #${colors.base0B};
      }

      element selected.urgent {
          background-color: rgba(${colors.base08-rgb-r}, ${colors.base08-rgb-g}, ${colors.base08-rgb-b}, 0.2);
          text-color: #${colors.base08};
      }

      element alternate.normal {
          background-color: transparent;
          text-color: #${colors.base05};
      }

      element alternate.active {
          background-color: transparent;
          text-color: #${colors.base0B};
      }

      element alternate.urgent {
          background-color: transparent;
          text-color: #${colors.base08};
      }

      scrollbar {
          width: 4px;
          border: 0px;
          handle-width: 8px;
          padding: 0px;
          background-color: transparent;
          handle-color: #${colors.base05};
      }

      message {
          border: 0px;
          padding: 0px;
          background-color: transparent;
      }

      textbox {
          text-color: #${colors.base05};
          background-color: transparent;
      }
    '';
  };
}
