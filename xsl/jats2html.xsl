<?xml version="1.0" encoding="UTF-8"?>
<!--
  * plugins/generic/ojsbrJatsViewer/xsl/jats2html.xsl
  *
  * Copyright (c) 2026 OJSBR (https://ojsbr.com)
  * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
  *
  * Turns one language of a JATS article (the main article or one of its
  * sub-article translations, SciELO SPS style) into an HTML fragment that is
  * shown inside the page of the journal theme.
  *
  * Output, in one <div>:
  *   <ol id="ojsbrJats-figlist">    entries of the figures panel
  *   <ol id="ojsbrJats-tablelist">  entries of the tables panel
  *   <article id="ojsbrJats-article"> the text
  *
  * Safety: the XML comes from third parties. Nothing is copied as is: every
  * element is mapped to a known HTML element, attributes are chosen one by one,
  * links only keep http(s), mailto and ftp addresses, and the stylesheet reads
  * no other document. The PHP side forbids file and network access.
  -->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:xlink="http://www.w3.org/1999/xlink"
	xmlns:mml="http://www.w3.org/1998/Math/MathML"
	exclude-result-prefixes="xlink mml">

	<xsl:output method="html" encoding="UTF-8" indent="no"/>

	<!-- Language to show: the main article or a translation. -->
	<xsl:param name="lang"/>

	<!-- Labels, translated by the plugin into the language shown. -->
	<xsl:param name="l_abstract" select="'Abstract'"/>
	<xsl:param name="l_keywords" select="'Keywords'"/>
	<xsl:param name="l_references" select="'References'"/>
	<xsl:param name="l_notes" select="'Notes'"/>
	<xsl:param name="l_acknowledgments" select="'Acknowledgments'"/>
	<xsl:param name="l_articleInfo" select="'Article information'"/>
	<xsl:param name="l_aboutAuthors" select="'About the authors'"/>
	<xsl:param name="l_received" select="'Received'"/>
	<xsl:param name="l_revised" select="'Revised'"/>
	<xsl:param name="l_accepted" select="'Accepted'"/>
	<xsl:param name="l_published" select="'Published'"/>
	<xsl:param name="l_license" select="'License'"/>
	<xsl:param name="l_copyright" select="'Copyright'"/>
	<xsl:param name="l_funding" select="'Funding'"/>
	<xsl:param name="l_correspondence" select="'Correspondence'"/>
	<xsl:param name="l_imageUnavailable" select="'Image not available'"/>
	<xsl:param name="l_orcid" select="'ORCID'"/>
	<xsl:param name="l_appendix" select="'Appendix'"/>

	<xsl:key name="byId" match="*[@id]" use="@id"/>

	<xsl:variable name="mainFront" select="/article/front/article-meta"/>
	<xsl:variable name="transLangs" select="/article/sub-article[@article-type='translation']/@xml:lang"/>
	<xsl:variable name="sub" select="/article/sub-article[@article-type='translation' and @xml:lang=$lang][1]"/>
	<xsl:variable name="front" select="$sub/front-stub | $sub/front/article-meta | $mainFront[not($sub)]"/>
	<xsl:variable name="body" select="$sub/body | /article/body[not($sub)]"/>
	<xsl:variable name="back" select="$sub/back | /article/back[not($sub)]"/>
	<xsl:variable name="floats" select="/article/floats-group[not($sub)] | $sub/floats-group"/>
	<!-- A translation without its own references shows those of the main article. -->
	<xsl:variable name="inheritedRefs" select="/article/back/ref-list[$sub and not($sub/back/ref-list)]"/>

	<xsl:variable name="contribGroups" select="$front/contrib-group | $mainFront[not($front/contrib-group)]/contrib-group"/>
	<xsl:variable name="ownAffs" select="$front/aff | $front/contrib-group/aff"/>
	<xsl:variable name="affs" select="$ownAffs | $mainFront[not($ownAffs)]/aff | $mainFront[not($ownAffs)]/contrib-group/aff"/>

	<xsl:variable name="lower" select="'abcdefghijklmnopqrstuvwxyz'"/>
	<xsl:variable name="upper" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>

	<!-- ============================================================ page -->

	<xsl:template match="/">
		<div>
			<xsl:if test="article">
				<ol id="ojsbrJats-figlist">
					<xsl:apply-templates select="($body | $back | $floats)//fig" mode="panel"/>
				</ol>
				<ol id="ojsbrJats-tablelist">
					<xsl:apply-templates select="($body | $back | $floats)//table-wrap" mode="panel"/>
				</ol>
				<article id="ojsbrJats-article" class="ojsbrJats-article" lang="{$lang}">
					<xsl:call-template name="header"/>
					<xsl:call-template name="abstracts"/>
					<xsl:if test="$body">
						<div class="ojsbrJats-body">
							<xsl:apply-templates select="$body/node()"/>
						</div>
					</xsl:if>
					<xsl:call-template name="back"/>
					<xsl:if test="$floats">
						<div class="ojsbrJats-floats">
							<xsl:apply-templates select="$floats/node()"/>
						</div>
					</xsl:if>
					<xsl:call-template name="info"/>
					<xsl:call-template name="bios"/>
				</article>
			</xsl:if>
		</div>
	</xsl:template>

	<!-- ============================================================ header -->

	<xsl:template name="header">
		<xsl:variable name="title" select="$front/title-group/article-title | $mainFront[not($front/title-group/article-title)]/title-group/trans-title-group[@xml:lang=$lang]/trans-title"/>
		<xsl:variable name="subtitle" select="$front/title-group/subtitle | $mainFront[not($front/title-group/article-title)]/title-group/trans-title-group[@xml:lang=$lang]/trans-subtitle"/>
		<xsl:variable name="subject" select="($front/article-categories/subj-group[@subj-group-type='heading']/subject | $mainFront[not($front/article-categories)]/article-categories/subj-group[@subj-group-type='heading']/subject)[1]"/>
		<header class="ojsbrJats-header">
			<xsl:if test="$subject">
				<p class="ojsbrJats-subject"><xsl:apply-templates select="$subject/node()"/></p>
			</xsl:if>
			<h1 class="ojsbrJats-title">
				<xsl:apply-templates select="$title[1]/node()"/>
				<xsl:if test="$subtitle">
					<xsl:text>: </xsl:text>
					<span class="ojsbrJats-subtitle"><xsl:apply-templates select="$subtitle[1]/node()"/></span>
				</xsl:if>
			</h1>
			<xsl:if test="$contribGroups/contrib">
				<ul class="ojsbrJats-contribs">
					<xsl:apply-templates select="$contribGroups/contrib" mode="header"/>
				</ul>
			</xsl:if>
			<xsl:if test="$affs">
				<ol class="ojsbrJats-affs">
					<xsl:apply-templates select="$affs" mode="header"/>
				</ol>
			</xsl:if>
		</header>
	</xsl:template>

	<xsl:template match="contrib" mode="header">
		<li class="ojsbrJats-contrib">
			<xsl:call-template name="contrib-name"/>
			<xsl:for-each select="xref[@ref-type='aff' or @ref-type='corresp' or @ref-type='fn']">
				<xsl:apply-templates select="."/>
			</xsl:for-each>
			<xsl:for-each select="contrib-id[@contrib-id-type='orcid'][1]">
				<xsl:text> </xsl:text>
				<a class="ojsbrJats-orcid">
					<xsl:attribute name="href">
						<xsl:call-template name="orcid-url"><xsl:with-param name="id" select="."/></xsl:call-template>
					</xsl:attribute>
					<span aria-hidden="true">iD</span>
					<span class="ojsbrJats-sr">
						<xsl:value-of select="$l_orcid"/>
						<xsl:text> </xsl:text>
						<xsl:call-template name="contrib-name-text"><xsl:with-param name="contrib" select=".."/></xsl:call-template>
					</span>
				</a>
			</xsl:for-each>
		</li>
	</xsl:template>

	<!-- https://orcid.org/ + the last 19 characters (0000-0000-0000-000X), whatever came before. -->
	<xsl:template name="orcid-url">
		<xsl:param name="id"/>
		<xsl:variable name="clean" select="translate(normalize-space($id), ' ', '')"/>
		<xsl:value-of select="concat('https://orcid.org/', substring($clean, string-length($clean) - 18))"/>
	</xsl:template>

	<xsl:template name="contrib-name">
		<xsl:choose>
			<xsl:when test="name">
				<span class="ojsbrJats-name"><xsl:apply-templates select="name[1]" mode="name"/></span>
			</xsl:when>
			<xsl:when test="string-name">
				<span class="ojsbrJats-name"><xsl:apply-templates select="string-name[1]/node()"/></span>
			</xsl:when>
			<xsl:when test="collab">
				<span class="ojsbrJats-name"><xsl:apply-templates select="collab[1]/node()"/></span>
			</xsl:when>
			<xsl:when test="name-alternatives/name">
				<span class="ojsbrJats-name"><xsl:apply-templates select="name-alternatives/name[1]" mode="name"/></span>
			</xsl:when>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="contrib-name-text">
		<xsl:param name="contrib"/>
		<xsl:for-each select="$contrib">
			<xsl:choose>
				<xsl:when test="name">
					<xsl:value-of select="normalize-space(concat(name[1]/prefix, ' ', name[1]/given-names, ' ', name[1]/surname, ' ', name[1]/suffix))"/>
				</xsl:when>
				<xsl:otherwise><xsl:value-of select="normalize-space((string-name | collab | name-alternatives/name)[1])"/></xsl:otherwise>
			</xsl:choose>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="name" mode="name">
		<xsl:if test="prefix"><xsl:apply-templates select="prefix/node()"/><xsl:text> </xsl:text></xsl:if>
		<xsl:apply-templates select="given-names/node()"/>
		<xsl:if test="given-names and surname"><xsl:text> </xsl:text></xsl:if>
		<xsl:apply-templates select="surname/node()"/>
		<xsl:if test="suffix"><xsl:text> </xsl:text><xsl:apply-templates select="suffix/node()"/></xsl:if>
	</xsl:template>

	<xsl:template match="aff" mode="header">
		<li>
			<xsl:call-template name="id"/>
			<sup class="ojsbrJats-afflabel">
				<xsl:choose>
					<xsl:when test="label"><xsl:apply-templates select="label/node()"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="count(preceding-sibling::aff) + 1"/></xsl:otherwise>
				</xsl:choose>
			</sup>
			<xsl:text> </xsl:text>
			<xsl:variable name="original" select="normalize-space(institution[@content-type='original'])"/>
			<xsl:variable name="orgname" select="normalize-space(institution[@content-type='orgname'][1])"/>
			<xsl:choose>
				<!-- SciELO keeps the affiliation as written by the author, when it is complete. -->
				<xsl:when test="$original != '' and ($orgname = '' or contains($original, $orgname))">
					<xsl:apply-templates select="institution[@content-type='original'][1]/node()"/>
				</xsl:when>
				<!-- Punctuation written in the XML: keep it as it is. -->
				<xsl:when test="text()[normalize-space()]">
					<xsl:apply-templates select="node()[not(self::label or self::institution[@content-type='original'])]"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:for-each select="institution[not(@content-type='original')] | addr-line/* | addr-line[not(*)] | city | state | country | email">
						<xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
						<xsl:apply-templates select="."/>
					</xsl:for-each>
				</xsl:otherwise>
			</xsl:choose>
		</li>
	</xsl:template>

	<!-- ============================================================ abstracts -->

	<xsl:template name="abstracts">
		<xsl:apply-templates select="$front/abstract" mode="abstract"/>
		<xsl:apply-templates select="$front/trans-abstract[not(@xml:lang = $transLangs)]" mode="abstract"/>
		<!-- Keywords without an abstract in the same language. -->
		<xsl:for-each select="$front/kwd-group">
			<xsl:variable name="kl">
				<xsl:choose>
					<xsl:when test="@xml:lang"><xsl:value-of select="@xml:lang"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="$lang"/></xsl:otherwise>
				</xsl:choose>
			</xsl:variable>
			<xsl:variable name="shown" select="$front/abstract[(@xml:lang and @xml:lang = $kl) or (not(@xml:lang) and $kl = $lang)] | $front/trans-abstract[not(@xml:lang = $transLangs)][@xml:lang = $kl]"/>
			<xsl:if test="not($shown) and ($kl = $lang or (not($sub) and not($kl = $transLangs)))">
				<xsl:apply-templates select="." mode="kwd"/>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="abstract | trans-abstract" mode="abstract">
		<xsl:variable name="al">
			<xsl:choose>
				<xsl:when test="@xml:lang"><xsl:value-of select="@xml:lang"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="$lang"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<section class="ojsbrJats-abstract">
			<xsl:if test="$al != $lang"><xsl:attribute name="lang"><xsl:value-of select="$al"/></xsl:attribute></xsl:if>
			<xsl:call-template name="id"/>
			<h2>
				<xsl:choose>
					<xsl:when test="title"><xsl:apply-templates select="title[1]/node()"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="$l_abstract"/></xsl:otherwise>
				</xsl:choose>
			</h2>
			<xsl:apply-templates select="node()[not(self::title or self::label)]"/>
			<!-- The keywords in the language of this abstract. -->
			<xsl:apply-templates select="$front/kwd-group[@xml:lang = $al or (not(@xml:lang) and $al = $lang)]" mode="kwd"/>
		</section>
	</xsl:template>

	<xsl:template match="kwd-group" mode="kwd">
		<p class="ojsbrJats-keywords">
			<xsl:if test="@xml:lang and @xml:lang != $lang"><xsl:attribute name="lang"><xsl:value-of select="@xml:lang"/></xsl:attribute></xsl:if>
			<strong>
				<xsl:variable name="title" select="normalize-space(title[1])"/>
				<xsl:choose>
					<!-- SciELO often writes the colon in the title ("Palavras-chave:"): only one is shown. -->
					<xsl:when test="substring($title, string-length($title)) = ':'">
						<xsl:value-of select="normalize-space(substring($title, 1, string-length($title) - 1))"/>
					</xsl:when>
					<xsl:when test="title"><xsl:apply-templates select="title[1]/node()"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="$l_keywords"/></xsl:otherwise>
				</xsl:choose>
				<xsl:text>: </xsl:text>
			</strong>
			<xsl:for-each select="kwd | compound-kwd">
				<xsl:if test="position() &gt; 1"><xsl:text>; </xsl:text></xsl:if>
				<xsl:apply-templates select="node()"/>
			</xsl:for-each>
		</p>
	</xsl:template>

	<!-- ============================================================ back -->

	<xsl:template name="back">
		<xsl:if test="$back or $inheritedRefs">
			<div class="ojsbrJats-back">
				<xsl:apply-templates select="$back/node()[not(self::fn-group)]"/>
				<xsl:apply-templates select="$inheritedRefs">
					<xsl:with-param name="inherited" select="true()"/>
				</xsl:apply-templates>
				<xsl:apply-templates select="$back/fn-group"/>
			</div>
		</xsl:if>
	</xsl:template>

	<xsl:template match="back/title | back/label"/>

	<xsl:template match="ack | app | glossary | notes | bio[not(ancestor::contrib)]">
		<section>
			<xsl:attribute name="class">ojsbrJats-<xsl:value-of select="local-name()"/></xsl:attribute>
			<xsl:call-template name="id"/>
			<xsl:call-template name="heading">
				<xsl:with-param name="default">
					<xsl:choose>
						<xsl:when test="self::ack"><xsl:value-of select="$l_acknowledgments"/></xsl:when>
						<xsl:when test="self::app"><xsl:value-of select="$l_appendix"/></xsl:when>
						<xsl:when test="self::notes"><xsl:value-of select="$l_notes"/></xsl:when>
					</xsl:choose>
				</xsl:with-param>
			</xsl:call-template>
			<xsl:apply-templates select="node()[not(self::title or self::label)]"/>
		</section>
	</xsl:template>

	<xsl:template match="app-group">
		<div class="ojsbrJats-app-group">
			<xsl:call-template name="id"/>
			<xsl:call-template name="heading"/>
			<xsl:apply-templates select="node()[not(self::title or self::label)]"/>
		</div>
	</xsl:template>

	<xsl:template match="ref-list">
		<xsl:param name="inherited" select="false()"/>
		<section class="ojsbrJats-refs">
			<xsl:call-template name="id"/>
			<xsl:choose>
				<xsl:when test="$inherited">
					<h2><xsl:value-of select="$l_references"/></h2>
				</xsl:when>
				<xsl:otherwise>
					<xsl:call-template name="heading">
						<xsl:with-param name="default" select="$l_references"/>
					</xsl:call-template>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:apply-templates select="node()[not(self::title or self::label or self::ref)]"/>
			<xsl:if test="ref">
				<ol class="ojsbrJats-reflist">
					<xsl:apply-templates select="ref"/>
				</ol>
			</xsl:if>
		</section>
	</xsl:template>

	<xsl:template match="ref">
		<xsl:variable name="mixed" select="(mixed-citation[@xml:lang=$lang] | mixed-citation)[1]"/>
		<xsl:variable name="element" select="(element-citation[@xml:lang=$lang] | element-citation)[1]"/>
		<li>
			<xsl:call-template name="id"/>
			<xsl:if test="label and not($mixed and starts-with(normalize-space($mixed), normalize-space(label)))">
				<span class="ojsbrJats-reflabel"><xsl:apply-templates select="label/node()"/></span>
				<xsl:text> </xsl:text>
			</xsl:if>
			<xsl:choose>
				<xsl:when test="$mixed">
					<xsl:apply-templates select="$mixed/node()"/>
					<!-- DOI known only by the structured citation. -->
					<xsl:variable name="doi" select="normalize-space($element/pub-id[@pub-id-type='doi'])"/>
					<xsl:if test="$doi != '' and not($mixed//pub-id[@pub-id-type='doi']) and not(contains($mixed, $doi))">
						<xsl:text> </xsl:text>
						<a class="ojsbrJats-doi" href="{concat('https://doi.org/', $doi)}"><xsl:value-of select="concat('https://doi.org/', $doi)"/></a>
					</xsl:if>
				</xsl:when>
				<xsl:when test="$element">
					<xsl:apply-templates select="$element" mode="cite"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:apply-templates select="node()[not(self::label)]"/>
				</xsl:otherwise>
			</xsl:choose>
		</li>
	</xsl:template>

	<!-- A readable line from a structured citation (no style is imposed). -->
	<xsl:template match="element-citation | nlm-citation" mode="cite">
		<xsl:for-each select="person-group">
			<xsl:for-each select="name | string-name | collab">
				<xsl:if test="position() &gt; 1"><xsl:text>; </xsl:text></xsl:if>
				<xsl:choose>
					<xsl:when test="self::name">
						<xsl:apply-templates select="surname/node()"/>
						<xsl:if test="given-names"><xsl:text>, </xsl:text><xsl:apply-templates select="given-names/node()"/></xsl:if>
					</xsl:when>
					<xsl:otherwise><xsl:apply-templates select="node()"/></xsl:otherwise>
				</xsl:choose>
			</xsl:for-each>
			<xsl:if test="etal"><xsl:text> et al.</xsl:text></xsl:if>
			<!-- No second full stop after an initial ("Silva, A."). -->
			<xsl:variable name="names" select="normalize-space(.)"/>
			<xsl:if test="etal or substring($names, string-length($names)) != '.'"><xsl:text>.</xsl:text></xsl:if>
			<xsl:text> </xsl:text>
		</xsl:for-each>
		<xsl:for-each select="article-title | chapter-title | part-title | data-title">
			<xsl:apply-templates select="node()"/><xsl:text>. </xsl:text>
		</xsl:for-each>
		<xsl:if test="source">
			<em><xsl:apply-templates select="source[1]/node()"/></em>
		</xsl:if>
		<xsl:if test="edition"><xsl:text>, </xsl:text><xsl:apply-templates select="edition[1]/node()"/></xsl:if>
		<xsl:if test="volume"><xsl:text>, </xsl:text><xsl:apply-templates select="volume[1]/node()"/></xsl:if>
		<xsl:if test="issue"><xsl:text>(</xsl:text><xsl:apply-templates select="issue[1]/node()"/><xsl:text>)</xsl:text></xsl:if>
		<xsl:if test="fpage">
			<xsl:text>, </xsl:text><xsl:apply-templates select="fpage[1]/node()"/>
			<xsl:if test="lpage"><xsl:text>–</xsl:text><xsl:apply-templates select="lpage[1]/node()"/></xsl:if>
		</xsl:if>
		<xsl:if test="elocation-id"><xsl:text>, </xsl:text><xsl:apply-templates select="elocation-id[1]/node()"/></xsl:if>
		<xsl:if test="publisher-loc or publisher-name">
			<xsl:text>. </xsl:text>
			<xsl:apply-templates select="publisher-loc[1]/node()"/>
			<xsl:if test="publisher-loc and publisher-name"><xsl:text>: </xsl:text></xsl:if>
			<xsl:apply-templates select="publisher-name[1]/node()"/>
		</xsl:if>
		<xsl:if test="year"><xsl:text>, </xsl:text><xsl:apply-templates select="year[1]/node()"/></xsl:if>
		<xsl:text>.</xsl:text>
		<xsl:for-each select="pub-id | ext-link | uri">
			<xsl:text> </xsl:text>
			<xsl:apply-templates select="."/>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="fn-group">
		<section class="ojsbrJats-fngroup">
			<xsl:call-template name="id"/>
			<xsl:call-template name="heading">
				<xsl:with-param name="default" select="$l_notes"/>
			</xsl:call-template>
			<ul class="ojsbrJats-fns">
				<xsl:for-each select="fn">
					<li>
						<xsl:call-template name="id"/>
						<xsl:apply-templates select="." mode="fn-content"/>
					</li>
				</xsl:for-each>
			</ul>
		</section>
	</xsl:template>

	<xsl:template match="fn" mode="fn-content">
		<xsl:if test="label">
			<span class="ojsbrJats-fnlabel"><xsl:apply-templates select="label/node()"/></span>
			<xsl:text> </xsl:text>
		</xsl:if>
		<xsl:apply-templates select="node()[not(self::label)]"/>
	</xsl:template>

	<!-- A footnote written where it is cited. -->
	<xsl:template match="fn">
		<span class="ojsbrJats-inlinefn">
			<xsl:call-template name="id"/>
			<xsl:apply-templates select="." mode="fn-content"/>
		</span>
	</xsl:template>

	<!-- ============================================================ article information -->

	<xsl:template name="info">
		<xsl:variable name="doi" select="($front/article-id[@pub-id-type='doi'] | $mainFront[not($front/article-id[@pub-id-type='doi'])]/article-id[@pub-id-type='doi'])[1]"/>
		<xsl:variable name="history" select="($front/history | $mainFront[not($front/history)]/history)[1]"/>
		<xsl:variable name="pubDate" select="($mainFront/pub-date[@date-type='pub'] | $mainFront/pub-date[@pub-type='epub'] | $mainFront/pub-date)[1]"/>
		<xsl:variable name="permissions" select="($front/permissions | $mainFront[not($front/permissions)]/permissions)[1]"/>
		<xsl:variable name="funding" select="$front/funding-group | $mainFront[not($front/funding-group)]/funding-group"/>
		<xsl:variable name="notes" select="$front/author-notes/*"/>
		<xsl:if test="$doi or $history/date or $pubDate or $permissions/* or $funding/* or $notes">
			<section class="ojsbrJats-info">
				<h2><xsl:value-of select="$l_articleInfo"/></h2>
				<dl>
					<xsl:if test="$doi">
						<dt>DOI</dt>
						<dd><a href="{concat('https://doi.org/', normalize-space($doi))}"><xsl:value-of select="concat('https://doi.org/', normalize-space($doi))"/></a></dd>
					</xsl:if>
					<xsl:for-each select="$history/date[@date-type='received']">
						<dt><xsl:value-of select="$l_received"/></dt>
						<dd><xsl:call-template name="date"/></dd>
					</xsl:for-each>
					<xsl:for-each select="$history/date[@date-type='rev-recd']">
						<dt><xsl:value-of select="$l_revised"/></dt>
						<dd><xsl:call-template name="date"/></dd>
					</xsl:for-each>
					<xsl:for-each select="$history/date[@date-type='accepted']">
						<dt><xsl:value-of select="$l_accepted"/></dt>
						<dd><xsl:call-template name="date"/></dd>
					</xsl:for-each>
					<xsl:choose>
						<xsl:when test="$history/date[@date-type='pub']">
							<xsl:for-each select="$history/date[@date-type='pub'][1]">
								<dt><xsl:value-of select="$l_published"/></dt>
								<dd><xsl:call-template name="date"/></dd>
							</xsl:for-each>
						</xsl:when>
						<xsl:when test="$pubDate">
							<xsl:for-each select="$pubDate">
								<dt><xsl:value-of select="$l_published"/></dt>
								<dd><xsl:call-template name="date"/></dd>
							</xsl:for-each>
						</xsl:when>
					</xsl:choose>
					<xsl:for-each select="$notes">
						<xsl:choose>
							<xsl:when test="self::corresp">
								<dt><xsl:value-of select="$l_correspondence"/></dt>
								<dd><xsl:call-template name="id"/><xsl:apply-templates select="node()[not(self::label)]"/></dd>
							</xsl:when>
							<xsl:when test="self::fn">
								<dt><xsl:apply-templates select="label/node()"/></dt>
								<dd><xsl:call-template name="id"/><xsl:apply-templates select="node()[not(self::label)]"/></dd>
							</xsl:when>
							<xsl:when test="self::p">
								<dd><xsl:apply-templates select="node()"/></dd>
							</xsl:when>
						</xsl:choose>
					</xsl:for-each>
					<xsl:for-each select="$funding/funding-statement | $funding/award-group[not(../funding-statement)]">
						<dt><xsl:value-of select="$l_funding"/></dt>
						<dd><xsl:apply-templates select="."/></dd>
					</xsl:for-each>
					<xsl:for-each select="$permissions/copyright-statement">
						<dt><xsl:value-of select="$l_copyright"/></dt>
						<dd><xsl:apply-templates select="node()"/></dd>
					</xsl:for-each>
					<xsl:for-each select="$permissions/license">
						<dt><xsl:value-of select="$l_license"/></dt>
						<dd>
							<xsl:apply-templates select="license-p/node()"/>
							<xsl:variable name="href"><xsl:call-template name="safe-href"><xsl:with-param name="href" select="@xlink:href"/></xsl:call-template></xsl:variable>
							<xsl:if test="$href != '' and not(.//ext-link[@xlink:href = current()/@xlink:href])">
								<xsl:text> </xsl:text>
								<a href="{$href}" rel="license noopener"><xsl:value-of select="$href"/></a>
							</xsl:if>
						</dd>
					</xsl:for-each>
				</dl>
			</section>
		</xsl:if>
	</xsl:template>

	<xsl:template match="award-group">
		<xsl:for-each select="funding-source | award-id">
			<xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
			<xsl:apply-templates select="node()"/>
		</xsl:for-each>
	</xsl:template>

	<!-- ISO 8601: unambiguous in any language. -->
	<xsl:template name="date">
		<xsl:choose>
			<xsl:when test="@iso-8601-date"><xsl:value-of select="@iso-8601-date"/></xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="normalize-space(year)"/>
				<xsl:if test="month">-<xsl:value-of select="substring(concat('0', normalize-space(month)), string-length(normalize-space(month)))"/></xsl:if>
				<xsl:if test="month and day">-<xsl:value-of select="substring(concat('0', normalize-space(day)), string-length(normalize-space(day)))"/></xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="bios">
		<xsl:if test="$contribGroups/contrib/bio">
			<section class="ojsbrJats-bios">
				<h2><xsl:value-of select="$l_aboutAuthors"/></h2>
				<dl>
					<xsl:for-each select="$contribGroups/contrib[bio]">
						<dt><xsl:call-template name="contrib-name"/></dt>
						<xsl:for-each select="bio">
							<dd><xsl:apply-templates select="node()[not(self::title)]"/></dd>
						</xsl:for-each>
					</xsl:for-each>
				</dl>
			</section>
		</xsl:if>
	</xsl:template>

	<!-- ============================================================ panels -->

	<xsl:template match="fig" mode="panel">
		<xsl:variable name="graphic" select="(graphic | alternatives/graphic)[1]"/>
		<li>
			<a>
				<xsl:attribute name="href">#<xsl:call-template name="anchor"/></xsl:attribute>
				<xsl:if test="$graphic">
					<xsl:variable name="src"><xsl:call-template name="graphic-src"><xsl:with-param name="g" select="$graphic"/></xsl:call-template></xsl:variable>
					<xsl:if test="$src != ''">
						<img class="ojsbrJats-thumb" src="{$src}" alt="" loading="lazy"/>
					</xsl:if>
				</xsl:if>
				<xsl:call-template name="panel-text"/>
			</a>
		</li>
	</xsl:template>

	<xsl:template match="table-wrap" mode="panel">
		<li>
			<a>
				<xsl:attribute name="href">#<xsl:call-template name="anchor"/></xsl:attribute>
				<xsl:call-template name="panel-text"/>
			</a>
		</li>
	</xsl:template>

	<xsl:template name="panel-text">
		<span class="ojsbrJats-panellabel">
			<xsl:choose>
				<xsl:when test="label"><xsl:value-of select="normalize-space(label)"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="position()"/></xsl:otherwise>
			</xsl:choose>
		</span>
		<xsl:variable name="caption" select="normalize-space((caption/title | caption/p)[1])"/>
		<xsl:if test="$caption != ''">
			<xsl:text> </xsl:text>
			<span class="ojsbrJats-panelcaption">
				<xsl:choose>
					<xsl:when test="string-length($caption) &gt; 160"><xsl:value-of select="concat(substring($caption, 1, 157), '…')"/></xsl:when>
					<xsl:otherwise><xsl:value-of select="$caption"/></xsl:otherwise>
				</xsl:choose>
			</span>
		</xsl:if>
	</xsl:template>

	<!-- ============================================================ body -->

	<xsl:template match="sec">
		<section>
			<xsl:call-template name="id"/>
			<xsl:if test="@sec-type"><xsl:attribute name="class">ojsbrJats-sec-<xsl:value-of select="translate(@sec-type, ' |', '--')"/></xsl:attribute></xsl:if>
			<xsl:call-template name="heading"/>
			<xsl:apply-templates select="node()[not(self::title or self::label or self::sec-meta)]"/>
		</section>
	</xsl:template>

	<!-- h2 for a top level section, one level more for each section around it. -->
	<xsl:template name="heading">
		<xsl:param name="default" select="''"/>
		<xsl:variable name="depth" select="count(ancestor::sec | ancestor::abstract | ancestor::trans-abstract | ancestor::app | ancestor::boxed-text | ancestor::app-group | ancestor::ref-list | ancestor::glossary) + 2"/>
		<xsl:variable name="level">
			<xsl:choose>
				<xsl:when test="$depth &gt; 6">6</xsl:when>
				<xsl:otherwise><xsl:value-of select="$depth"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:if test="title[normalize-space()] or label[normalize-space()] or $default != ''">
			<xsl:element name="h{$level}">
				<xsl:if test="label[normalize-space()]">
					<span class="ojsbrJats-label"><xsl:apply-templates select="label[1]/node()"/></span>
					<xsl:if test="title[normalize-space()]"><xsl:text> </xsl:text></xsl:if>
				</xsl:if>
				<xsl:choose>
					<xsl:when test="title[normalize-space()]"><xsl:apply-templates select="title[1]/node()"/></xsl:when>
					<xsl:when test="not(label[normalize-space()])"><xsl:value-of select="$default"/></xsl:when>
				</xsl:choose>
			</xsl:element>
		</xsl:if>
	</xsl:template>

	<xsl:template match="title | label | alt-text | long-desc | object-id | sec-meta | front-stub | processing-meta"/>

	<xsl:template match="p">
		<xsl:choose>
			<!-- An HTML paragraph cannot hold these. -->
			<xsl:when test="fig | fig-group | table-wrap | table-wrap-group | list | def-list | disp-quote | disp-formula | disp-formula-group | boxed-text | graphic | preformat | code | supplementary-material | statement | speech | media | array | chem-struct-wrap">
				<div class="ojsbrJats-p"><xsl:apply-templates/></div>
			</xsl:when>
			<xsl:otherwise>
				<p>
					<xsl:if test="@xml:lang and @xml:lang != $lang"><xsl:attribute name="lang"><xsl:value-of select="@xml:lang"/></xsl:attribute></xsl:if>
					<xsl:apply-templates/>
				</p>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="disp-quote">
		<blockquote class="ojsbrJats-quote">
			<xsl:call-template name="id"/>
			<xsl:apply-templates select="node()[not(self::attrib)]"/>
			<xsl:if test="attrib">
				<footer><xsl:apply-templates select="attrib/node()"/></footer>
			</xsl:if>
		</blockquote>
	</xsl:template>

	<xsl:template match="boxed-text | statement | speech">
		<aside>
			<xsl:attribute name="class">ojsbrJats-<xsl:value-of select="local-name()"/></xsl:attribute>
			<xsl:call-template name="id"/>
			<xsl:call-template name="heading"/>
			<xsl:apply-templates select="node()[not(self::title or self::label)]"/>
		</aside>
	</xsl:template>

	<xsl:template match="speaker"><strong><xsl:apply-templates/></strong><xsl:text> </xsl:text></xsl:template>

	<xsl:template match="list">
		<xsl:variable name="type" select="@list-type"/>
		<xsl:choose>
			<xsl:when test="$type = 'order' or $type = 'alpha-lower' or $type = 'alpha-upper' or $type = 'roman-lower' or $type = 'roman-upper'">
				<ol>
					<xsl:call-template name="id"/>
					<xsl:choose>
						<xsl:when test="$type = 'alpha-lower'"><xsl:attribute name="type">a</xsl:attribute></xsl:when>
						<xsl:when test="$type = 'alpha-upper'"><xsl:attribute name="type">A</xsl:attribute></xsl:when>
						<xsl:when test="$type = 'roman-lower'"><xsl:attribute name="type">i</xsl:attribute></xsl:when>
						<xsl:when test="$type = 'roman-upper'"><xsl:attribute name="type">I</xsl:attribute></xsl:when>
					</xsl:choose>
					<xsl:apply-templates select="list-item"/>
				</ol>
			</xsl:when>
			<xsl:otherwise>
				<ul>
					<xsl:call-template name="id"/>
					<xsl:if test="$type = 'simple' or list-item/label"><xsl:attribute name="class">ojsbrJats-list-simple</xsl:attribute></xsl:if>
					<xsl:apply-templates select="list-item"/>
				</ul>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="list-item">
		<li>
			<xsl:call-template name="id"/>
			<xsl:if test="label"><span class="ojsbrJats-label"><xsl:apply-templates select="label/node()"/></span><xsl:text> </xsl:text></xsl:if>
			<xsl:apply-templates select="node()[not(self::label)]"/>
		</li>
	</xsl:template>

	<xsl:template match="def-list">
		<dl class="ojsbrJats-deflist">
			<xsl:call-template name="id"/>
			<xsl:for-each select="def-item">
				<dt><xsl:apply-templates select="term/node()"/></dt>
				<xsl:for-each select="def"><dd><xsl:apply-templates/></dd></xsl:for-each>
			</xsl:for-each>
		</dl>
	</xsl:template>

	<xsl:template match="glossary/def-list | glossary/glossary">
		<xsl:call-template name="def-list-or-section"/>
	</xsl:template>

	<xsl:template name="def-list-or-section">
		<xsl:choose>
			<xsl:when test="self::def-list">
				<dl class="ojsbrJats-deflist">
					<xsl:for-each select="def-item">
						<dt><xsl:apply-templates select="term/node()"/></dt>
						<xsl:for-each select="def"><dd><xsl:apply-templates/></dd></xsl:for-each>
					</xsl:for-each>
				</dl>
			</xsl:when>
			<xsl:otherwise>
				<section><xsl:call-template name="heading"/><xsl:apply-templates select="node()[not(self::title or self::label)]"/></section>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="preformat | code">
		<pre class="ojsbrJats-pre"><xsl:call-template name="id"/><code><xsl:value-of select="."/></code></pre>
	</xsl:template>

	<!-- ============================================================ figures -->

	<xsl:template match="fig-group">
		<div class="ojsbrJats-figgroup">
			<xsl:call-template name="id"/>
			<xsl:if test="label or caption">
				<p class="ojsbrJats-caption">
					<xsl:if test="label"><strong><xsl:apply-templates select="label/node()"/></strong><xsl:text> </xsl:text></xsl:if>
					<xsl:apply-templates select="caption/title/node()"/>
				</p>
			</xsl:if>
			<xsl:apply-templates select="fig"/>
		</div>
	</xsl:template>

	<xsl:template match="fig">
		<figure class="ojsbrJats-fig">
			<xsl:attribute name="id"><xsl:call-template name="anchor"/></xsl:attribute>
			<xsl:variable name="graphic" select="(graphic | alternatives/graphic)[1]"/>
			<xsl:choose>
				<xsl:when test="$graphic">
					<xsl:apply-templates select="$graphic" mode="img">
						<xsl:with-param name="alt" select="normalize-space((alt-text | $graphic/alt-text | caption/title | label)[1])"/>
					</xsl:apply-templates>
				</xsl:when>
				<xsl:otherwise>
					<xsl:apply-templates select="node()[not(self::label or self::caption or self::attrib or self::permissions)]"/>
				</xsl:otherwise>
			</xsl:choose>
			<xsl:call-template name="figcaption"/>
		</figure>
	</xsl:template>

	<xsl:template name="figcaption">
		<xsl:if test="label or caption or attrib or permissions">
			<figcaption>
				<xsl:if test="label or caption/title">
					<p class="ojsbrJats-caption">
						<xsl:if test="label"><strong class="ojsbrJats-label"><xsl:apply-templates select="label/node()"/></strong><xsl:text> </xsl:text></xsl:if>
						<xsl:apply-templates select="caption/title/node()"/>
					</p>
				</xsl:if>
				<xsl:apply-templates select="caption/node()[not(self::title)]"/>
				<xsl:for-each select="attrib | permissions/copyright-statement | permissions/license/license-p">
					<p class="ojsbrJats-attrib"><xsl:apply-templates select="node()"/></p>
				</xsl:for-each>
			</figcaption>
		</xsl:if>
	</xsl:template>

	<!-- Address of an image: the file of the galley the plugin found for it, or a web address. -->
	<xsl:template name="graphic-src">
		<xsl:param name="g"/>
		<xsl:choose>
			<xsl:when test="$g/@data-ojsbr-src"><xsl:value-of select="$g/@data-ojsbr-src"/></xsl:when>
			<xsl:otherwise>
				<xsl:variable name="h" select="normalize-space($g/@xlink:href)"/>
				<xsl:variable name="start" select="translate(substring($h, 1, 8), $upper, $lower)"/>
				<xsl:if test="starts-with($start, 'https://') or starts-with($start, 'http://')"><xsl:value-of select="$h"/></xsl:if>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="graphic | inline-graphic" mode="img">
		<xsl:param name="alt" select="normalize-space(alt-text)"/>
		<xsl:variable name="src"><xsl:call-template name="graphic-src"><xsl:with-param name="g" select="."/></xsl:call-template></xsl:variable>
		<xsl:choose>
			<xsl:when test="$src != ''">
				<img src="{$src}" alt="{$alt}" loading="lazy">
					<xsl:attribute name="class">
						<xsl:choose>
							<xsl:when test="self::inline-graphic">ojsbrJats-inlineimg</xsl:when>
							<xsl:otherwise>ojsbrJats-img</xsl:otherwise>
						</xsl:choose>
					</xsl:attribute>
				</img>
			</xsl:when>
			<xsl:otherwise>
				<span class="ojsbrJats-missing"><xsl:value-of select="$l_imageUnavailable"/></span>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="graphic | inline-graphic">
		<xsl:apply-templates select="." mode="img"/>
	</xsl:template>

	<xsl:template match="alternatives">
		<xsl:choose>
			<xsl:when test="mml:math"><xsl:apply-templates select="mml:math[1]"/></xsl:when>
			<xsl:when test="table"><xsl:apply-templates select="table[1]"/></xsl:when>
			<xsl:when test="graphic | inline-graphic"><xsl:apply-templates select="(graphic | inline-graphic)[1]"/></xsl:when>
			<xsl:otherwise><xsl:apply-templates select="*[1]"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="media | supplementary-material | inline-supplementary-material">
		<xsl:variable name="href">
			<xsl:choose>
				<xsl:when test="@data-ojsbr-src"><xsl:value-of select="@data-ojsbr-src"/></xsl:when>
				<xsl:otherwise><xsl:call-template name="safe-href"><xsl:with-param name="href" select="@xlink:href"/></xsl:call-template></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="text">
			<xsl:if test="label"><strong><xsl:apply-templates select="label/node()"/></strong><xsl:text> </xsl:text></xsl:if>
			<xsl:apply-templates select="caption/title/node()"/>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="self::inline-supplementary-material">
				<xsl:choose>
					<xsl:when test="$href != ''"><a href="{$href}"><xsl:apply-templates/></a></xsl:when>
					<xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<div class="ojsbrJats-supplementary">
					<xsl:call-template name="id"/>
					<p>
						<xsl:copy-of select="$text"/>
						<xsl:if test="$href != ''">
							<xsl:text> </xsl:text>
							<a href="{$href}"><xsl:value-of select="$href"/></a>
						</xsl:if>
					</p>
					<xsl:apply-templates select="caption/node()[not(self::title)]"/>
				</div>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- ============================================================ tables -->

	<xsl:template match="table-wrap-group">
		<div class="ojsbrJats-tablegroup">
			<xsl:call-template name="id"/>
			<xsl:apply-templates select="table-wrap"/>
		</div>
	</xsl:template>

	<xsl:template match="table-wrap">
		<figure class="ojsbrJats-table">
			<xsl:attribute name="id"><xsl:call-template name="anchor"/></xsl:attribute>
			<xsl:if test="label or caption">
				<figcaption>
					<p class="ojsbrJats-caption">
						<xsl:if test="label"><strong class="ojsbrJats-label"><xsl:apply-templates select="label/node()"/></strong><xsl:text> </xsl:text></xsl:if>
						<xsl:apply-templates select="caption/title/node()"/>
					</p>
					<xsl:apply-templates select="caption/node()[not(self::title)]"/>
				</figcaption>
			</xsl:if>
			<div class="ojsbrJats-tablescroll" tabindex="0" role="region">
				<xsl:attribute name="aria-label">
					<xsl:value-of select="normalize-space(concat(label, ' ', caption/title))"/>
				</xsl:attribute>
				<xsl:choose>
					<xsl:when test="table"><xsl:apply-templates select="table"/></xsl:when>
					<xsl:when test="alternatives"><xsl:apply-templates select="alternatives"/></xsl:when>
					<xsl:when test="graphic">
						<xsl:apply-templates select="graphic[1]" mode="img">
							<xsl:with-param name="alt" select="normalize-space((alt-text | graphic/alt-text | caption/title | label)[1])"/>
						</xsl:apply-templates>
					</xsl:when>
				</xsl:choose>
			</div>
			<xsl:for-each select="table-wrap-foot">
				<div class="ojsbrJats-tablefoot">
					<xsl:apply-templates select="node()[not(self::title)]"/>
				</div>
			</xsl:for-each>
			<xsl:for-each select="attrib | permissions/copyright-statement">
				<p class="ojsbrJats-attrib"><xsl:apply-templates select="node()"/></p>
			</xsl:for-each>
		</figure>
	</xsl:template>

	<xsl:template match="table-wrap-foot/fn | table-wrap-foot/fn-group/fn">
		<p class="ojsbrJats-tablefn">
			<xsl:call-template name="id"/>
			<xsl:apply-templates select="." mode="fn-content"/>
		</p>
	</xsl:template>

	<xsl:template match="table-wrap-foot/fn-group"><xsl:apply-templates select="fn"/></xsl:template>

	<xsl:template match="table | thead | tbody | tfoot | tr | th | td | col | colgroup">
		<xsl:element name="{local-name()}">
			<xsl:if test="self::table"><xsl:attribute name="class">ojsbrJats-tablegrid</xsl:attribute></xsl:if>
			<xsl:for-each select="@colspan | @rowspan | @span">
				<xsl:if test="string(number(.)) != 'NaN'">
					<xsl:attribute name="{local-name()}"><xsl:value-of select="number(.)"/></xsl:attribute>
				</xsl:if>
			</xsl:for-each>
			<xsl:if test="@scope = 'row' or @scope = 'col' or @scope = 'rowgroup' or @scope = 'colgroup'">
				<xsl:attribute name="scope"><xsl:value-of select="@scope"/></xsl:attribute>
			</xsl:if>
			<xsl:if test="(self::td or self::th) and (@align = 'left' or @align = 'center' or @align = 'right' or @align = 'justify')">
				<xsl:attribute name="class">ojsbrJats-align-<xsl:value-of select="@align"/></xsl:attribute>
			</xsl:if>
			<xsl:apply-templates/>
		</xsl:element>
	</xsl:template>

	<xsl:template match="table/caption">
		<caption><xsl:apply-templates/></caption>
	</xsl:template>

	<!-- ============================================================ formulas -->

	<xsl:template match="disp-formula">
		<div class="ojsbrJats-formula">
			<xsl:call-template name="id"/>
			<xsl:apply-templates select="node()[not(self::label)]"/>
			<xsl:if test="label"><span class="ojsbrJats-formulalabel"><xsl:apply-templates select="label/node()"/></span></xsl:if>
		</div>
	</xsl:template>

	<xsl:template match="disp-formula-group">
		<div class="ojsbrJats-formulagroup"><xsl:call-template name="id"/><xsl:apply-templates/></div>
	</xsl:template>

	<xsl:template match="inline-formula">
		<span class="ojsbrJats-inlineformula"><xsl:call-template name="id"/><xsl:apply-templates/></span>
	</xsl:template>

	<xsl:template match="tex-math">
		<code class="ojsbrJats-tex"><xsl:value-of select="."/></code>
	</xsl:template>

	<!-- MathML, shown by the browser. Only presentation attributes are kept. -->
	<xsl:template match="mml:*">
		<xsl:element name="{local-name()}">
			<xsl:for-each select="@*[namespace-uri() = '']">
				<xsl:variable name="n" select="translate(local-name(), $upper, $lower)"/>
				<xsl:if test="not(starts-with($n, 'on')) and $n != 'href' and $n != 'src' and $n != 'style' and $n != 'xmlns' and not(contains($n, ':'))">
					<xsl:attribute name="{local-name()}"><xsl:value-of select="."/></xsl:attribute>
				</xsl:if>
			</xsl:for-each>
			<xsl:apply-templates select="mml:* | text()"/>
		</xsl:element>
	</xsl:template>

	<!-- ============================================================ inline -->

	<xsl:template match="italic"><i><xsl:apply-templates/></i></xsl:template>
	<xsl:template match="bold"><b><xsl:apply-templates/></b></xsl:template>
	<xsl:template match="sup"><sup><xsl:apply-templates/></sup></xsl:template>
	<xsl:template match="sub"><sub><xsl:apply-templates/></sub></xsl:template>
	<xsl:template match="underline"><u><xsl:apply-templates/></u></xsl:template>
	<xsl:template match="strike"><s><xsl:apply-templates/></s></xsl:template>
	<xsl:template match="monospace"><code><xsl:apply-templates/></code></xsl:template>
	<xsl:template match="sc"><span class="ojsbrJats-sc"><xsl:apply-templates/></span></xsl:template>
	<xsl:template match="overline"><span class="ojsbrJats-overline"><xsl:apply-templates/></span></xsl:template>
	<xsl:template match="roman | sans-serif | named-content | styled-content | chem-struct | institution | city | state | country | addr-line | email[ancestor::aff]">
		<span><xsl:apply-templates/></span>
	</xsl:template>
	<xsl:template match="abbrev">
		<abbr>
			<xsl:if test="def"><xsl:attribute name="title"><xsl:value-of select="normalize-space(def)"/></xsl:attribute></xsl:if>
			<xsl:apply-templates select="node()[not(self::def)]"/>
		</abbr>
	</xsl:template>
	<xsl:template match="break"><br/></xsl:template>
	<xsl:template match="hr"><hr/></xsl:template>
	<xsl:template match="q"><q><xsl:apply-templates/></q></xsl:template>

	<xsl:template match="email">
		<xsl:variable name="address" select="normalize-space(.)"/>
		<xsl:choose>
			<xsl:when test="contains($address, '@') and not(contains($address, ' ')) and not(contains($address, ':'))">
				<a href="{concat('mailto:', $address)}"><xsl:value-of select="$address"/></a>
			</xsl:when>
			<xsl:otherwise><xsl:value-of select="$address"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="ext-link | uri | self-uri">
		<xsl:variable name="target">
			<xsl:choose>
				<xsl:when test="@xlink:href"><xsl:value-of select="normalize-space(@xlink:href)"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:variable name="href">
			<xsl:choose>
				<xsl:when test="@ext-link-type = 'doi' and starts-with($target, '10.')"><xsl:value-of select="concat('https://doi.org/', $target)"/></xsl:when>
				<xsl:otherwise><xsl:call-template name="safe-href"><xsl:with-param name="href" select="$target"/></xsl:call-template></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="$href != ''">
				<a href="{$href}" rel="noopener"><xsl:apply-templates/></a>
			</xsl:when>
			<xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="pub-id">
		<xsl:variable name="id" select="normalize-space(.)"/>
		<xsl:choose>
			<xsl:when test="@pub-id-type = 'doi' and $id != ''">
				<a class="ojsbrJats-doi" href="{concat('https://doi.org/', substring-after(concat('#', $id), substring-before(concat('#', $id), '10.')))}">
					<xsl:apply-templates/>
				</a>
			</xsl:when>
			<xsl:when test="@pub-id-type = 'pmid' and string(number($id)) != 'NaN'">
				<a href="{concat('https://pubmed.ncbi.nlm.nih.gov/', $id, '/')}"><xsl:apply-templates/></a>
			</xsl:when>
			<xsl:otherwise><xsl:apply-templates/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="xref">
		<xsl:variable name="rid" select="substring-before(concat(normalize-space(@rid), ' '), ' ')"/>
		<xsl:variable name="target" select="key('byId', $rid)"/>
		<xsl:variable name="content">
			<xsl:choose>
				<xsl:when test="normalize-space(.) != '' or *"><xsl:apply-templates/></xsl:when>
				<xsl:when test="$target/label"><xsl:value-of select="normalize-space($target/label)"/></xsl:when>
				<xsl:when test="$target/self::aff"><xsl:value-of select="count($target/preceding-sibling::aff) + 1"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="$rid"/></xsl:otherwise>
			</xsl:choose>
		</xsl:variable>
		<xsl:choose>
			<xsl:when test="not($target)"><xsl:copy-of select="$content"/></xsl:when>
			<xsl:when test="(@ref-type = 'fn' or @ref-type = 'aff' or @ref-type = 'corresp' or @ref-type = 'table-fn' or @ref-type = 'author-notes') and not(sup)">
				<sup class="ojsbrJats-xref"><a href="{concat('#', 'j-', $rid)}"><xsl:copy-of select="$content"/></a></sup>
			</xsl:when>
			<xsl:otherwise>
				<a class="ojsbrJats-xref" href="{concat('#', 'j-', $rid)}"><xsl:copy-of select="$content"/></a>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- ============================================================ helpers -->

	<!-- Ids of the XML get a prefix so that they never clash with those of the theme. -->
	<xsl:template name="id">
		<xsl:if test="@id">
			<xsl:attribute name="id"><xsl:value-of select="concat('j-', @id)"/></xsl:attribute>
		</xsl:if>
	</xsl:template>

	<!-- Figures and tables always need an anchor, for the panels. -->
	<xsl:template name="anchor">
		<xsl:choose>
			<xsl:when test="@id"><xsl:value-of select="concat('j-', @id)"/></xsl:when>
			<xsl:otherwise><xsl:value-of select="concat('j-g-', generate-id())"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<xsl:template name="safe-href">
		<xsl:param name="href"/>
		<xsl:variable name="h" select="normalize-space($href)"/>
		<xsl:variable name="start" select="translate(substring($h, 1, 8), $upper, $lower)"/>
		<xsl:if test="starts-with($start, 'https://') or starts-with($start, 'http://') or starts-with($start, 'mailto:') or starts-with($start, 'ftp://')">
			<xsl:value-of select="$h"/>
		</xsl:if>
	</xsl:template>

	<!-- Anything else: its text, never its markup. -->
	<xsl:template match="*">
		<xsl:apply-templates/>
	</xsl:template>

	<xsl:template match="text()">
		<xsl:value-of select="."/>
	</xsl:template>

	<xsl:template match="comment() | processing-instruction()"/>

</xsl:stylesheet>
