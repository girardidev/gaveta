---
# gaveta-uusp
title: 'Marco 5: App da menu bar'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:25Z
updated_at: 2026-10-08T13:09:46Z
parent: gaveta-zs8f
blocked_by:
    - gaveta-8lnw
---

MenuBarExtra, observa folders.json, pausar, copiar config, iniciar com o macOS.

- [x] Observador de folders.json testado (atualiza em < 1 s), pausar grava no JSON
- [x] Conferência visual do popover pelo usuário (screenshot); corrigido caminho abreviado (~)

## Summary of Changes

App da menu bar (alvo GavetaApp, MenuBarExtra estilo janela) com lista de pastas, selos, pausar por interruptor, abrir no Finder, copiar config MCP por cliente, iniciar com o macOS e sair. FolderObserver com DispatchSource (atualiza em < 1 s). ClientConfig e PathDisplay no GavetaCore. Scripts/make-app.sh monta build/Gaveta.app. 97 testes no Core, 12 MCP, 4 App.
