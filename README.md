# Multilingual JATS Viewer (ojsbrJatsViewer)

[Português](#português) · [English](#english)

## English

Plugin for **OJS 3.5** that shows JATS XML galleys as HTML built on the server, inside the journal theme.

- **Language selector** for the main article and each translation embedded in the XML as `<sub-article article-type="translation" xml:lang="…">` (SciELO SPS). Each language has its own address (`?lang=en`), and the page lists the others with `hreflang`. The first language shown is the one of the interface, when the XML has it; otherwise the language of the main article.
- **Figures and Tables panels**, each shown only when the text has items of that kind. An article with tables and no figure has a Tables panel.
- Title, authors with affiliations and ORCID, abstracts and keywords, sections, lists, quotes, notes, MathML formulas (shown by the browser), tables, figures with captions, references with links to the DOI, history, license and DOI of the article.
- Images are taken from the dependent files of the galley, as with the Lens Galley plugin (`fig1.jpg` or just `fig1` in the XML).
- The text is in the HTML of the page, so search engines can read it.
- A file that is not well-formed XML, or not a JATS article, shows a message with a link to download it.

### Works with the Lens Galley plugin

The plugin answers the same hook as the Lens Galley (`ArticleHandler::view::galley`), just before it. While it is enabled, XML galleys open with this viewer; disable it and the Lens is used again. The download of the galley still returns the original XML file.

### Statistics

The reader no longer downloads the XML to read it, as with the Lens, so each view of the page is counted as the core counts a download of the galley file.

### Security

The XML comes from third parties:

- the file is parsed without network access, without loading the DTD and without replacing external entities (XXE);
- the stylesheet runs with every file and network access forbidden and without PHP functions;
- every XML element is mapped to a known HTML element, attributes are chosen one by one, and links only keep `http(s)`, `mailto` and `ftp` addresses (no `javascript:` or `data:`).

### Cache

The HTML of every language of a galley is kept in `cache/ojsbrJatsViewer/<galley id>/`. A new galley file, a changed image or a new version of the plugin makes a new entry, and the old one is removed.

### Requirements

- OJS 3.5.0.x, PHP 8.2 or 8.3;
- PHP extensions `dom`, `xsl` and `intl`.

### Installation

Copy the folder to `plugins/generic/ojsbrJatsViewer`, then enable **Multilingual JATS Viewer** in *Website › Plugins*.

### License

GNU GPL v3 (see `LICENSE`). The stylesheet `xsl/jats2html.xsl` was written for this plugin. The HTML generator of SciELO packtools (BSD-2-Clause) was studied but is not included: it builds a whole SciELO page with Bootstrap and jQuery, which does not fit in a journal theme.

### Use of AI

This plugin was written with the help of generative AI, under the review and responsibility of OJSBR.

---

## Português

Plugin para o **OJS 3.5** que exibe as composições em XML JATS como HTML gerado no servidor, dentro do tema da revista.

- **Seletor de idioma** para o artigo principal e cada tradução embutida no XML como `<sub-article article-type="translation" xml:lang="…">` (SciELO SPS). Cada idioma tem endereço próprio (`?lang=en`), e a página indica os demais com `hreflang`. O idioma inicial é o da interface, quando o XML o tem; senão, o do artigo principal.
- **Painéis de Figuras e de Tabelas**, cada um só aparece se o texto tiver itens desse tipo. Artigo só com tabelas tem painel de Tabelas.
- Título, autores com afiliações e ORCID, resumos e palavras-chave, seções, listas, citações, notas, fórmulas em MathML (o navegador desenha), tabelas, figuras com legenda, referências com link para o DOI, histórico, licença e DOI do artigo.
- As imagens vêm dos arquivos dependentes da composição, como no Lens Galley (`fig1.jpg` ou só `fig1` no XML).
- O texto fica no HTML da página, legível pelos buscadores.
- Arquivo que não é XML bem formado, ou não é artigo JATS, mostra uma mensagem com link para baixá-lo.

### Convive com o Lens Galley

O plugin responde ao mesmo gancho do Lens Galley (`ArticleHandler::view::galley`), logo antes dele. Enquanto estiver habilitado, as composições XML abrem neste visualizador; desabilitado, volta o Lens. O download da composição continua devolvendo o arquivo XML original.

### Estatísticas

O leitor não baixa mais o XML para ler, como no Lens, por isso cada visualização da página é contada como o núcleo conta o download do arquivo da composição.

### Segurança

O XML vem de terceiros:

- o arquivo é lido sem acesso à rede, sem carregar a DTD e sem substituir entidades externas (XXE);
- a folha de estilo roda com todo acesso a arquivo e rede proibido e sem funções PHP;
- cada elemento do XML vira um elemento HTML conhecido, os atributos são escolhidos um a um e os links só mantêm endereços `http(s)`, `mailto` e `ftp` (nada de `javascript:` nem `data:`).

### Cache

O HTML de todos os idiomas de uma composição fica em `cache/ojsbrJatsViewer/<id da composição>/`. Arquivo novo na composição, imagem trocada ou versão nova do plugin geram uma entrada nova, e a antiga é apagada.

### Requisitos

- OJS 3.5.0.x, PHP 8.2 ou 8.3;
- extensões do PHP `dom`, `xsl` e `intl`.

### Instalação

Copie a pasta para `plugins/generic/ojsbrJatsViewer` e habilite **Visualizador JATS multilíngue** em *Site › Plugins*.

### Licença

GNU GPL v3 (veja `LICENSE`). A folha de estilo `xsl/jats2html.xsl` foi escrita para este plugin. O gerador de HTML do SciELO packtools (BSD-2-Clause) foi estudado, mas não está incluído: ele monta uma página inteira da SciELO com Bootstrap e jQuery, que não cabe no tema da revista.

### Uso de IA

Este plugin foi escrito com o auxílio de IA generativa, sob revisão e responsabilidade da OJSBR.
