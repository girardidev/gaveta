---
# gaveta-y924
title: 'Marco 2: CLI'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:25Z
updated_at: 2026-10-08T11:11:47Z
parent: gaveta-zs8f
blocked_by:
    - gaveta-kjau
---

add, remove, list, pause, resume com mensagens em português e regras de recusa.

## Summary of Changes

FolderManager no GavetaCore (add com todas as recusas, remove por alias ou caminho, pause/resume) e alvo GavetaCLI (binário gaveta) com add, remove, list [--json], pause, resume. Erros em português no stderr, saída 1 em falha. 51 testes passando e CLI verificada manualmente.
