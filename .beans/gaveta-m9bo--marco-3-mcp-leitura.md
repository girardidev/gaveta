---
# gaveta-m9bo
title: 'Marco 3: MCP leitura'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:25Z
updated_at: 2026-10-08T12:57:35Z
parent: gaveta-zs8f
blocked_by:
    - gaveta-y924
---

list_folders, list_dir, read_file, stat via stdio. Testar com Inspector e Claude Desktop.

## Summary of Changes

FileTools no GavetaCore (list_dir, read_file, stat), servidor MCP stdio (alvo GavetaMCP, comando gaveta mcp) com log de atividade. Verificado com cliente Python, MCP Inspector CLI e OpenCode. Dois bugs de segurança achados e corrigidos: open() bloqueante em FIFO e symlink quebrado revelando alvo inexistente.
