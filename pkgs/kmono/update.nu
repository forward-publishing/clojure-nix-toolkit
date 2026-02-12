#!/usr/bin/env nu

let release = (gh api repos/kepler16/kmono/releases/latest | from json)
let version = ($release.tag_name | str replace "v" "")

let checksums_url = ($release.assets
  | where name == "checksums.txt"
  | first
  | get browser_download_url)
let checksums = (http get $checksums_url | decode utf-8)

let platform_map = {
  "linux-amd64": "x86_64-linux",
  "linux-arm64": "aarch64-linux",
  "macos-amd64": "x86_64-darwin",
  "macos-arm64": "aarch64-darwin",
}

let entries = ($checksums
  | lines
  | where { $in != "" }
  | each { |line|
    let parts = ($line | split row "  ")
    let hex_hash = $parts.0
    let platform = ($parts.1 | path basename | str replace ".tar.gz" "" | str replace "kmono-" "")
    {platform: $platform, hex_hash: $hex_hash}
  }
  | where { |row| ($row.platform) in ($platform_map | columns) }
  | each { |row|
    let system = ($platform_map | get $row.platform)
    let sha256 = (nix hash convert --to sri --hash-algo sha256 $row.hex_hash | str trim)
    let url = $"https://github.com/kepler16/kmono/releases/download/v($version)/kmono-($row.platform).tar.gz"
    {system: $system, coord: {url: $url, sha256: $sha256}}
  }
  | select system coord
  | transpose -rd
)

let final = {
  version: $version
  platforms: $entries
}

$final
  | to json
  | nix eval --pretty --impure --expr 'builtins.fromJSON (builtins.readFile /dev/stdin)'
  | save -f coords.nix
