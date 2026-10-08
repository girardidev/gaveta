---
# gaveta-8lnw
title: 'Marco 4: MCP search e write_file'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:25Z
updated_at: 2026-10-08T12:59:46Z
parent: gaveta-zs8f
blocked_by:
    - gaveta-m9bo
---

search e write_file (só com pasta readwrite).

## Summary of Changes

search (literal, glob com **, {a,b}, limite 200, ignora .git/node_modules/.DS_Store/binários/symlinks) e write_file (atômico, só readwrite, mantém permissões, 1 MB) no GavetaCore. No servidor MCP, write_file só aparece em tools/list enquanto houver pasta readwrite ativa, com notificação list_changed ao mudar. 89 testes no Core e 12 no MCP; verificação ponta a ponta por stdio.
