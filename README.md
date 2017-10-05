# packer-wrapper
Non-trivial invocations of [Packer](https://github.com/hashicorp/packer) often find it useful to stack Variables and other run-time environmentals in an effort to reuse templates. This tends to result in very long command-lines since the program doesn't handle wildcards. Since it can only consume JSON (which unlike YAML doesn't lend itself to being pieced from fragments), outright duplication of templates with very minor differences is common-place.

This tool simplifies Packer invocation in the general case, and if provided with YAML files, transparently merges them with [YamlReader](https://github.com/tb3088/yamlreader) into a template while preserving Packer's subsequent token substitution capability.
