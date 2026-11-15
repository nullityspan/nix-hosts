"""Nix extractor (tree-sitter). Local addition, patched in by agents.nix.

Emits one node per file, one per top-level binding (`programs.helix`,
`options.foo.bar`, let-bound names) and an `imports_from` edge for every
relative path literal that resolves to a file in the tree.
"""
from __future__ import annotations

import ctypes
from pathlib import Path

from graphify.extractors.base import _file_stem, _make_id, _read_source_bytes, _read_text

_GRAMMAR = "@grammar@"
_ATTRSETS = ("attrset_expression", "rec_attrset_expression")
# Wrappers around the module body: `{ pkgs, ... }: let ... in with lib; { }`.
_TRANSPARENT = ("function_expression", "let_expression", "with_expression",
                "assert_expression", "parenthesized_expression")
# Namespaces that are one level deeper than the setting they hold.
_DEEP = ("options", "config")


def extract_nix(path: Path) -> dict:
    """Extract bindings and file imports from a .nix file."""
    try:
        from tree_sitter import Language, Parser
        lib = ctypes.CDLL(_GRAMMAR)
        lib.tree_sitter_nix.restype = ctypes.c_void_p
        source = _read_source_bytes(path)
        root = Parser(Language(lib.tree_sitter_nix())).parse(source).root_node
    except Exception as e:
        return {"nodes": [], "edges": [], "error": str(e)}

    stem = _file_stem(path)
    str_path = str(path)
    file_nid = _make_id(str_path)
    nodes = [{"id": file_nid, "label": path.name, "file_type": "code",
              "source_file": str_path, "source_location": "L1"}]
    edges: list[dict] = []
    seen = {file_nid}

    def add_edge(tgt: str, relation: str, line: int, **extra) -> None:
        edges.append({"source": file_nid, "target": tgt, "relation": relation,
                      "confidence": "EXTRACTED", "source_file": str_path,
                      "source_location": f"L{line}", "weight": 1.0, **extra})

    def bindings(bset, prefix: tuple[str, ...]) -> None:
        for b in bset.children:
            if b.type != "binding":
                continue
            attrpath = b.child_by_field_name("attrpath")
            value = b.child_by_field_name("expression")
            if attrpath is None:
                continue
            full = prefix + tuple(
                _read_text(c, source).strip('"') for c in attrpath.children if c.type != ".")
            depth = 3 if full[0] in _DEEP else 2
            if len(full) < depth and value is not None and value.type in _ATTRSETS:
                inner = next((c for c in value.children if c.type == "binding_set"), None)
                if inner is not None:
                    bindings(inner, full)
                    continue
            label = ".".join(full)
            nid = _make_id(stem, label)
            if nid not in seen:
                seen.add(nid)
                line = b.start_point[0] + 1
                nodes.append({"id": nid, "label": label, "file_type": "code",
                              "source_file": str_path, "source_location": f"L{line}"})
                add_edge(nid, "contains", line)

    def body(node) -> None:
        while node is not None and node.type in _TRANSPARENT:
            if node.type == "let_expression":
                for c in node.children:
                    if c.type == "binding_set":
                        bindings(c, ())
            node = node.child_by_field_name("body") or node.child_by_field_name("expression")
        if node is not None and node.type in _ATTRSETS:
            for c in node.children:
                if c.type == "binding_set":
                    bindings(c, ())

    def paths(node) -> None:
        if node.type == "path_expression":
            raw = _read_text(node, source)
            if raw.startswith(("./", "../")) and "${" not in raw:
                target = (path.parent / raw).resolve()
                if target.is_dir():
                    target = target / "default.nix"
                # Existence check keeps crafted `../../etc/passwd` out of the graph.
                if target.is_file() and target != path.resolve():
                    add_edge(_make_id(str(target)), "imports_from",
                             node.start_point[0] + 1, context="import",
                             target_file=str(target))
            return
        for c in node.children:
            paths(c)

    body(root.child_by_field_name("expression"))
    paths(root)
    return {"nodes": nodes, "edges": edges}
