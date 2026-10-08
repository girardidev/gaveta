---
# gaveta-kjau
title: 'Marco 1: GavetaCore'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:17Z
updated_at: 2026-10-08T11:06:30Z
parent: gaveta-zs8f
---

Modelo, JSON atômico, resolveAllowed e testes de segurança (Swift Testing). Parar e mostrar testes passando.

## Summary of Changes

GavetaCore criado: modelo (Folder, FoldersFile), FolderStore com escrita atômica, PathCanonicalizer (realpath + F_GETPATH) e AccessPolicy.resolveAllowed. 37 testes (Swift Testing) passando, cobrindo todos os casos obrigatórios do briefing.
