# skills

Coleção pessoal de **skills** para agentes de IA (Claude Code e afins). Este repositório é a fonte de publicação: cada skill que eu crio ou uso no dia a dia mora aqui, versionada e pronta para instalar.

> **Publicar uma skill = fazer commit dela aqui.** Consumidores instalam direto deste repositório.

## O que é uma skill

Cada diretório top-level é uma skill autocontida, instalada no contexto **global** do Claude Code (`~/.claude/`) — não por projeto. Uma skill entrega instruções/capacidades reutilizáveis para o agente, mais um instalador idempotente.

## Skills disponíveis

| Skill | Descrição | Instalação |
|---|---|---|
| [`draw-io/`](./draw-io) | Provisiona a skill oficial draw.io (`jgraph/drawio-mcp`) no contexto global, com um _house-theme_ flat e `adaptiveColors` para leitura confortável em light/dark. | `./draw-io/install-skill.sh` |

## Instalação

Cada skill traz seu próprio `install-skill.sh` — idempotente, seguro para re-rodar e para colar num `bootstrap.sh`:

```bash
chmod +x draw-io/install-skill.sh && ./draw-io/install-skill.sh
```

O instalador provisiona a skill em `~/.claude/` e imprime os passos de validação manual ao final. Não há build, lint ou suíte de testes no repositório — skills são instaladores shell + documentação, e a validação é por-skill e manual.

## Convenção de estrutura

```
skills/
├── CLAUDE.md              # guia da coleção (para o agente)
├── README.md              # este arquivo
└── <skill>/
    ├── install-skill.sh   # instalador idempotente (entry point)
    └── CLAUDE.md          # guia scoped da skill (opcional)
```

- **`install-skill.sh`** — entry point da skill. Idempotente: pode rodar quantas vezes quiser. Provisiona para `~/.claude/` e imprime a checagem manual.
- **`CLAUDE.md`** (por skill) — guia scoped ao diretório da skill. Documenta a arquitetura própria da skill, não a da coleção.

### A invariante das duas camadas (design do instalador)

Padrão central que todo instalador deve preservar (referência: `draw-io/install-skill.sh`): manter artefatos **upstream** separados das **customizações locais**, para que updates do upstream nunca sobrescrevam edits do usuário.

- **Upstream** (clonado/baixado a cada run) → `cp` / overwrite. Nunca editar à mão; mudanças se perdem no re-run.
- **Local** (temas, config, pointers) → escrito **só se faltar**, guardado por `[ -f ]` ou `grep -q`. Re-runs preservam.

Ao escrever ou editar um instalador: **clobber no upstream, guard no local.**

## Adicionando uma nova skill

1. Crie um diretório top-level com o nome da skill.
2. Adicione um `install-skill.sh` idempotente seguindo a invariante das duas camadas.
3. Adicione um `CLAUDE.md` scoped se a skill tiver arquitetura não-óbvia.
4. Registre a skill na tabela [Skills disponíveis](#skills-disponíveis) acima.
5. Faça commit — esse commit é a publicação.

## Convenções de Git

- **Conventional Commits + emoji.** Uma skill por PR.
- Branch a partir de `main` (`feature/<slug>`); nunca commit direto em `main`.
- SemVer em tags para releases.

## MCP

`.claude/settings.local.json` habilita o MCP server `graphify` para este repositório.
