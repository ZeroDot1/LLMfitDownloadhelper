#!/usr/bin/env python3
# ==============================================================================
# Application:   LLMfitDownloadhelper
# Author:        ZeroDot1
# Version:       2.0
# Platform:      Universal (Arch Linux & Ubuntu compatible)
# License:       GNU AGPLv3 (https://gnu.org)
#
# Copyright (C) 2026 ZeroDot1
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# ==============================================================================

import sys
import json
import subprocess
import re
import argparse

def get_compatible_models(tag_filter=None):
    mapping = {}
    try:
        # Run llmfit list --json to get all models
        result = subprocess.run(['llmfit', 'list', '--json'], capture_output=True, text=True, check=True)
        models = json.loads(result.stdout)
    except Exception:
        # If anything fails, return empty set
        return set()

    compatible = set()
    for model in models:
        name = model.get('name', '')
        gguf_sources = model.get('gguf_sources', [])
        ollama_name = model.get('ollama_name', None)
        
        is_native = '/' not in name
        has_gguf_sources = isinstance(gguf_sources, list) and len(gguf_sources) > 0
        is_gguf_repo = 'gguf' in name.lower()
        has_ollama_name = ollama_name is not None and ollama_name != ""
        
        if is_native or has_gguf_sources or is_gguf_repo or has_ollama_name:
            # Check tag filter if active
            if tag_filter:
                name_lower = name.lower()
                use_case_lower = model.get('use_case', '').lower()
                capabilities = [c.lower() for c in model.get('capabilities', [])]
                
                tag_matched = False
                tf = tag_filter.lower()
                if tf == 'coding':
                    tag_matched = 'coder' in name_lower or 'code' in name_lower or 'code' in use_case_lower
                elif tf == 'vision':
                    tag_matched = 'vision' in capabilities or 'vision' in use_case_lower or 'vision' in name_lower or '-vl' in name_lower or 'multimodal' in name_lower or 'multimodal' in use_case_lower
                elif tf == 'reasoning':
                    tag_matched = 'reasoning' in name_lower or 'reasoning' in use_case_lower or 'thinking' in name_lower or 'r1' in name_lower or 'o1' in name_lower
                elif tf == 'audio':
                    tag_matched = 'audio' in capabilities or 'audio' in use_case_lower or 'speech' in name_lower or 'whisper' in name_lower
                elif tf == 'general' or tf == 'chat':
                    tag_matched = 'chat' in name_lower or 'instruct' in name_lower or 'general' in use_case_lower or 'instruction' in use_case_lower
                
                if not tag_matched:
                    continue

            compatible.add(name)
            # Save mapping
            if has_gguf_sources:
                mapping[name] = gguf_sources[0].get('repo', name)
            elif has_ollama_name:
                mapping[name] = ollama_name
            else:
                mapping[name] = name
            
    # Write the mapping to a temporary JSON file
    try:
        with open('/tmp/llmfit_model_mapping.json', 'w') as f:
            json.dump(mapping, f)
    except Exception:
        pass

    return compatible

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--tag', type=str, default=None)
    parser.add_argument('--preview', type=str, default=None)
    parser.add_argument('--selected', type=str, nargs='*', default=None)
    args, unknown = parser.parse_known_args()

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

    # Handle preview mode
    if args.preview is not None:
        # Extract model names from selected list
        selected = []
        if args.selected:
            for s in args.selected:
                s_clean = ansi_escape.sub('', s).strip()
                s_clean = s_clean.replace('│', '').strip()
                if s_clean and s_clean not in selected and s_clean != "Model" and not s_clean.startswith("---"):
                    selected.append(s_clean)
        
        # If exactly 2 models are selected, run diff comparison
        if len(selected) == 2:
            subprocess.run(['llmfit', 'diff', selected[0], selected[1]])
        elif len(selected) > 2:
            print("=== Model Comparison ===")
            print("Please select exactly 2 models to compare.")
            print(f"Currently selected ({len(selected)}):")
            for s in selected:
                print(f" - {s}")
        else:
            # Show detailed info for focused model
            focused = ansi_escape.sub('', args.preview).strip()
            focused = focused.replace('│', '').strip()
            if focused and focused != "Model" and not focused.startswith("---"):
                subprocess.run(['llmfit', 'info', focused])
            else:
                print("No model selected.")
        return

    # Regular filter mode
    compatible = get_compatible_models(tag_filter=args.tag)
    
    # Read table lines from stdin
    for line in sys.stdin:
        parts = line.split('│')
        if len(parts) > 2:
            model_cell = parts[2].strip()
            model_name = ansi_escape.sub('', model_cell).strip()
            
            # If the cell is the header "Model" or is empty, print the line
            if model_name == "Model" or model_name == "":
                sys.stdout.write(line)
                continue
                
            # If we successfully loaded compatible models, filter by them
            if compatible:
                if model_name in compatible:
                    sys.stdout.write(line)
            else:
                sys.stdout.write(line)
        else:
            # Print non-row lines (headers, borders, footnotes)
            sys.stdout.write(line)

if __name__ == '__main__':
    main()
