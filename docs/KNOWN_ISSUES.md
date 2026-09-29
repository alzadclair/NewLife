# NEW LIFE ROBLOX — KNOWN ISSUES

## K-001 — Runtime Play Solo ainda não validado

O comando MCP `start_stop_play` foi bloqueado pelo revisor automático antes de iniciar o Play Solo. Portanto, boot completo Server/Client e console durante Play ainda precisam de execução assim que a operação for permitida.

## K-002 — Multiplayer local ainda não executado

O MCP disponível expõe `start_stop_play`, mas não apresentou uma operação separada para iniciar explicitamente um servidor local com múltiplos clientes. Como o Play foi bloqueado, a validação com 2 jogadores não pôde ser concluída nesta sessão.

## K-003 — Persistência real não validada

`Place1` está em contexto de desenvolvimento local e o serviço usa `StudioMemory` dentro do Studio. O caminho DataStore/UpdateAsync está preparado para ambiente publicado, mas requer teste em uma experiência publicada com acesso a DataStore.

## K-004 — MCP_TestPart permanece no Workspace

`MCP_TestPart` foi criado durante a validação anterior da conexão MCP e foi preservado deliberadamente. Não participa da arquitetura NewLife.
