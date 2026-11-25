{**
 * plugins/generic/ojsbrJatsViewer/templates/display.tpl
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * Page of an XML galley, inside the journal theme. The HTML of the article
 * ($jatsPart.article, .figures, .tables) is built by xsl/jats2html.xsl, which
 * escapes all the text of the XML.
 *
 * @uses $jatsPart array|null The language shown, or null when the XML cannot be shown
 * @uses $jatsLanguages array Code, name, address and state of each language
 *}
{capture assign="pageTitleTranslated"}{$galleyPublication->getLocalizedFullTitle(null, 'html')|strip_tags}{/capture}
{include file="frontend/components/header.tpl" pageTitleTranslated=$pageTitleTranslated}

<div class="page page_article ojsbrJats-page">
	{include file="frontend/components/breadcrumbs_article.tpl" currentTitle=$galley->getGalleyLabel()}

	{if !$isLatestPublication}
		<div class="cmp_notification notice ojsbrJats-notice" role="status">
			{translate key="submission.outdatedVersion" datePublished=$galleyPublication->getData('datePublished')|date_format:$dateFormatShort urlRecentVersion=$articleUrl|escape}
		</div>
	{/if}

	<div class="ojsbrJats-toolbar">
		<a class="ojsbrJats-return" href="{$articleUrl|escape}">{translate key="article.return"}</a>

		{if $jatsPart && $jatsLanguages|@count > 1}
			<nav class="ojsbrJats-languages" aria-labelledby="ojsbrJats-languages-label">
				<span id="ojsbrJats-languages-label" class="ojsbrJats-toolbarlabel">{translate key="plugins.generic.ojsbrJatsViewer.language"}</span>
				<ul>
					{foreach from=$jatsLanguages item=jatsLanguageLink}
						<li>
							<a href="{$jatsLanguageLink.url|escape}" hreflang="{$jatsLanguageLink.code|replace:'_':'-'|escape}"{if $jatsLanguageLink.current} aria-current="page" class="ojsbrJats-current"{/if}>
								{$jatsLanguageLink.label|escape}
							</a>
						</li>
					{/foreach}
				</ul>
			</nav>
		{/if}

		{if $jatsPart && $jatsPart.figureCount}
			<details class="ojsbrJats-panel ojsbrJats-panel-figures">
				<summary>{translate key="plugins.generic.ojsbrJatsViewer.figures" number=$jatsPart.figureCount}</summary>
				<ol class="ojsbrJats-panellist">{$jatsPart.figures}</ol>
			</details>
		{/if}

		{if $jatsPart && $jatsPart.tableCount}
			<details class="ojsbrJats-panel ojsbrJats-panel-tables">
				<summary>{translate key="plugins.generic.ojsbrJatsViewer.tables" number=$jatsPart.tableCount}</summary>
				<ol class="ojsbrJats-panellist">{$jatsPart.tables}</ol>
			</details>
		{/if}

		<a class="ojsbrJats-download" href="{$downloadUrl|escape}" download>{translate key="plugins.generic.ojsbrJatsViewer.downloadXml"}</a>
	</div>

	{if $jatsPart}
		{$jatsPart.article}
	{else}
		<div class="cmp_notification ojsbrJats-error" role="alert">
			{translate key="plugins.generic.ojsbrJatsViewer.error" url=$downloadUrl|escape}
		</div>
	{/if}
</div>

{include file="frontend/components/footer.tpl"}
