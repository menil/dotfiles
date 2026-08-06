{ lib }: {
  # Recursively generates home.file source mappings for everything under a directory
  # e.g., `./home/.config/starship.toml` -> `home.file.".config/starship.toml"`
  toHomeFiles = dir:
    let
      allFiles = lib.filesystem.listFilesRecursive dir;
      toRelPath = file:
        let
          dirStr = toString dir;
          fileStr = toString file;
          # Directory length + 1 to account for the trailing slash
          prefixLength = lib.stringLength dirStr + 1;
        in
        lib.substring prefixLength (lib.stringLength fileStr) fileStr;
    in
    lib.listToAttrs (map
      (file: {
        name = toRelPath file;
        value = { source = file; };
      })
      allFiles);
}
