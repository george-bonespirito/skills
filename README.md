# skills

Coleção pessoal de **skills** para agentes de IA (Claude Code, Cursor e afins).
Este repositório é a **fonte de publicação** e um **marketplace**: cada skill
mora aqui como um plugin autocontido, versionado e pronto para instalar.

> **Publicar = fazer commit aqui.** Consumidores instalam via marketplace.

## O que é uma skill / plugin

- **Skill** — uma pasta com `SKILL.md` na raiz (frontmatter `name` +
  `description`). Formato cross-agent: Claude Code, Cursor e outros leem o mesmo
  `SKILL.md`.
- **Plugin** — o bundle distribuível que carrega uma ou mais skills + manifesto.
  É o que o marketplace instala.

Glossário completo em [`CONTEXT.md`](./CONTEXT.md). Decisões de arquitetura em
[`docs/adr/`](./docs/adr/).

## Skills disponíveis

| Plugin | Descrição | Instalação |
|---|---|---|
| [`check-after-implementation/`](./check-after-implementation) | Após implementação: gates de qualidade e segurança em loop até ficarem verdes; twin bloqueante no GitHub Actions. | `/plugin install check-after-implementation@torgge-skills` |
| [`draw-io/`](./draw-io) | Gera diagramas draw.io editáveis e exporta como SVG com _house-theme_ flat/`adaptiveColors` (XML embarcado, legível em light/dark). | `/plugin install draw-io@torgge-skills` |

## Instalação

### Claude Code

Este repositório é um marketplace (`.claude-plugin/marketplace.json` na raiz):

```
/plugin marketplace add https://github.com/torgge/skills
/plugin install draw-io@torgge-skills
```

### Cursor

Cada plugin traz um `.cursor-plugin/plugin.json`. Instale pela
[Cursor Marketplace](https://cursor.com/marketplace) quando listado, ou aponte o
Cursor para o diretório do plugin.

## Estrutura

```
skills/
├── .claude-plugin/
│   └── marketplace.json       # marketplace Claude: lista os plugins
├── CONTEXT.md                 # glossário (ubiquitous language)
├── docs/adr/                  # decisões de arquitetura
├── README.md                  # este arquivo
└── <plugin>/
    ├── .claude-plugin/plugin.json   # manifesto Claude
    ├── .cursor-plugin/plugin.json   # manifesto Cursor
    ├── skills/<skill>/SKILL.md      # a skill (compartilhada pelos dois)
    ├── LICENSE
    └── README.md
```

Um `skills/` por plugin, dois manifestos apontando para ele — um repo, dois
marketplaces. Componentes ficam na raiz do plugin; só o manifesto vai no
diretório `.*-plugin/`.

## Adicionando uma nova skill

1. Crie um diretório top-level para o plugin.
2. Adicione `skills/<skill>/SKILL.md` (frontmatter `name` + `description`).
3. Adicione os manifestos `.claude-plugin/plugin.json` e
   `.cursor-plugin/plugin.json`, mais `LICENSE` e `README.md`.
4. Registre o plugin em `.claude-plugin/marketplace.json` e na tabela acima.
5. Faça commit — esse commit é a publicação.

## Convenções de Git

- **Conventional Commits + emoji.** Um plugin por PR.
- Branch a partir de `main` (`feature/<slug>`); nunca commit direto em `main`.
- SemVer nos manifestos (`version`) e em tags para releases.

## MCP

`.claude/settings.local.json` habilita o MCP server `graphify` para este repositório.
