---
# gaveta-2odp
title: 'Marco 7: Empacotamento'
status: completed
type: epic
priority: normal
created_at: 2026-10-08T11:04:25Z
updated_at: 2026-10-08T13:41:53Z
parent: gaveta-zs8f
blocked_by:
    - gaveta-mlfk
---

.app com binário, instalação do symlink, assinatura e notarização.

## Summary of Changes

CommandLineInstaller + gaveta install/uninstall (symlink em /usr/local/bin, idempotente, nunca sobrescreve arquivo comum, sugere sudo). VERSION file com teste de consistência. make-app.sh: universal (arm64+x86_64), hardened runtime, identidade e bundle id por variável de ambiente, assinatura de dentro para fora. release.sh: verificação (--check), assinatura Developer ID, notarização, staple, zip em dist/. Assinatura e notarização reais NÃO foram executadas (sem certificado).
