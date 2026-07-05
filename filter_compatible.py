#!/usr/bin/env python3
# ==============================================================================
# Application:   LLMfitDownloadhelper
# Author:        ZeroDot1
# Version:       1.7
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

def get_compatible_models():
    mapping = {}
    try:
        # Run llmfit list --json to get all models
        result = subprocess.run(['llmfit', 'list', '--json'], capture_output=True, text=True, check=True)
        models = json.loads(result.stdout)
    except Exception:
        # If anything fails, return empty dict
        return {}, {}

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
    compatible = get_compatible_models()
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    
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
