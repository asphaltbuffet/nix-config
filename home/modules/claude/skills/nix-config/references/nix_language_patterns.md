# Nix Language Patterns Reference

## Data Types

```nix
# Strings
"hello"                          # simple string
''
  multi-line
  string
''                               # indented string (strips leading whitespace)
"interpolation: ${pkgs.hello}"   # string interpolation

# Paths (not strings — no quotes)
./relative/path.nix
/absolute/path
<nixpkgs>                        # search path (avoid in flakes)

# Booleans
true false

# Integers
42

# Null
null

# Lists (space-separated, no commas)
[ 1 2 3 ]
[ pkgs.git pkgs.curl pkgs.wget ]

# Attribute sets
{ key = "value"; nested.key = "value"; }

# Recursive attribute sets (attrs can reference each other)
rec { x = 1; y = x + 1; }
```

## Functions

```nix
# Single argument
x: x + 1

# Pattern matching (destructured attrset)
{ pkgs, lib, ... }: { }          # ... accepts extra attrs

# Default values
{ pkgs, lib, config ? {}, ... }: { }

# Calling functions (space-separated, no parens)
builtins.map (x: x + 1) [ 1 2 3 ]
lib.mkDefault true
```

## Key Constructs

### let-in
```nix
let
  name = "world";
  greeting = "hello ${name}";
in
  greeting
```

### with
```nix
# Brings attrset into scope
with pkgs; [ git curl wget ]
# Preferred equivalent to: [ pkgs.git pkgs.curl pkgs.wget ]
```

### inherit
```nix
# Pull names from surrounding scope into attrset
{ inherit pkgs lib; }
# Equivalent to: { pkgs = pkgs; lib = lib; }

# Pull from another attrset
{ inherit (pkgs) git curl; }
# Equivalent to: { git = pkgs.git; curl = pkgs.curl; }
```

### if-then-else
```nix
if condition then "yes" else "no"
```

### import
```nix
import ./path.nix                # evaluate a .nix file
import ./path.nix { inherit pkgs; }  # call the function it returns
```

## NixOS/Home-Manager Module System

### Module structure
```nix
# Every module is a function returning an attrset
{ config, pkgs, lib, ... }: {
  imports = [ ./other-module.nix ];
  options = { };       # declare options (rare in config repos)
  config = { };        # set option values
  # shorthand: top-level keys ARE config when options is absent
}
```

### Priority functions
```nix
lib.mkDefault value    # low priority (can be overridden)
lib.mkForce value      # high priority (overrides everything)
lib.mkOverride 500 v   # custom priority (lower number = higher priority)
lib.mkIf cond value    # conditional value
lib.mkMerge [ a b ]    # merge multiple definitions
```

### Common option types
```nix
lib.mkOption {
  type = lib.types.str;              # string
  type = lib.types.bool;             # boolean
  type = lib.types.int;              # integer
  type = lib.types.path;             # path
  type = lib.types.package;          # nix package
  type = lib.types.listOf types.str; # list of strings
  type = lib.types.attrsOf types.str;# attrset of strings
  type = lib.types.nullOr types.str; # string or null
  type = lib.types.enum [ "a" "b" ]; # enum
}
```

## Flake Structure

```nix
{
  description = "...";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pin another input to same nixpkgs
    foo.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem { ... };
    homeConfigurations.user = home-manager.lib.homeManagerConfiguration { ... };
    devShells.x86_64-linux.default = pkgs.mkShell { ... };
    formatter.x86_64-linux = pkgs.alejandra;
  };
}
```

## Common Pitfalls

- **Missing semicolons**: Every attrset binding needs `;` — `{ x = 1; y = 2; }`
- **Commas in lists**: Lists use spaces, NOT commas — `[ a b c ]` not `[ a, b, c ]`
- **String escaping in `''` strings**: Use `'''` for literal `''`, and `''${` for literal `${`
- **Infinite recursion**: Using `with pkgs;` inside `pkgs` overlay causes recursion
- **Missing `...`**: Module functions must accept extra args — always include `...`
- **stateVersion**: Never change `stateVersion` on existing systems — it controls migration behavior, not the installed version
- **Shell Scripts**: Use `pkgs.writeShellApplication` to get benefits of `shellcheck` and ability to define script pkg dependencies

## Useful builtins and lib functions

```nix
builtins.readDir ./path           # list directory contents as attrset
builtins.readFile ./file          # read file as string
builtins.attrNames attrset        # list of keys
builtins.map fn list              # map over list
builtins.filter fn list           # filter list
builtins.listToAttrs list         # [{name; value}] → attrset
lib.mkDefault value               # set default priority
lib.mkForce value                 # force override
lib.mkIf condition value          # conditional
lib.optional condition value      # [value] if true, [] if false
lib.optionals condition list      # list if true, [] if false
lib.splitString sep str           # split string into list
lib.fileContents path             # read file, strip trailing newline
lib.genAttrs names fn             # generate attrset from list of names
```
