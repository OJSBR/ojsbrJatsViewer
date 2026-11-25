<?php

/**
 * @file plugins/generic/ojsbrJatsViewer/OjsbrJatsViewerPlugin.php
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * @class OjsbrJatsViewerPlugin
 *
 * @brief Shows a JATS XML galley as HTML built on the server, inside the
 *        journal theme, with a language selector for the main article and
 *        each translation (<sub-article article-type="translation">, SciELO
 *        SPS) and panels of figures and of tables.
 *
 *        It answers the same hook as the Lens Galley plugin, before it, so the
 *        Lens is used again as soon as this plugin is disabled. The download of
 *        the galley still returns the XML file.
 *
 *        Credits: it follows the approach of the Lens Galley plugin of the Public
 *        Knowledge Project (https://github.com/asmecher/lensGalley, GPL v3), built
 *        on eLife Lens (https://github.com/elifesciences/lens): the same hook, the
 *        images found among the dependent files of the galley, the same addresses
 *        for them. The multilingual model is the one of SciELO PS, studied in
 *        SciELO packtools (https://github.com/scieloorg/packtools).
 */

namespace APP\plugins\generic\ojsbrJatsViewer;

use APP\core\Application;
use APP\core\Request;
use APP\facades\Repo;
use APP\issue\Issue;
use APP\observers\events\UsageEvent;
use APP\plugins\generic\ojsbrJatsViewer\classes\JatsCache;
use APP\plugins\generic\ojsbrJatsViewer\classes\JatsDocument;
use APP\plugins\generic\ojsbrJatsViewer\classes\JatsRenderer;
use APP\publication\Publication;
use APP\submission\Submission;
use APP\template\TemplateManager;
use PKP\core\Core;
use PKP\db\DAORegistry;
use PKP\facades\Locale;
use PKP\galley\Galley;
use PKP\plugins\GenericPlugin;
use PKP\plugins\Hook;
use PKP\submission\Genre;
use PKP\submission\GenreDAO;
use PKP\submissionFile\SubmissionFile;

class OjsbrJatsViewerPlugin extends GenericPlugin
{
    /** Before the Lens Galley plugin, which uses the normal sequence. */
    public const HOOK_SEQUENCE = Hook::SEQUENCE_NORMAL - 1;

    public const XML_MIMETYPES = ['application/xml', 'text/xml'];

    /** Locale of the labels when the plugin has no translation for the language of the text. */
    public const FALLBACK_LOCALE = 'en';

    /** Locale of the labels for a language written without region: "pt" in a JATS file is almost always Brazilian Portuguese. */
    public const PREFERRED_LABEL_LOCALES = ['pt' => 'pt_BR', 'zh' => 'zh_Hans', 'sr' => 'sr_Latn', 'nb' => 'nb_NO', 'no' => 'nb_NO'];

    public function register($category, $path, $mainContextId = null): bool
    {
        $success = parent::register($category, $path, $mainContextId);
        if (Application::isUnderMaintenance()) {
            return $success;
        }

        // Only the reader page of a galley is changed, so the hook is registered
        // only where the plugin is enabled.
        if ($success && Application::get()->getName() === 'ojs2' && $this->getEnabled($mainContextId)) {
            Hook::add('ArticleHandler::view::galley', $this->viewGalley(...), self::HOOK_SEQUENCE);
        }

        return $success;
    }

    public function getDisplayName(): string
    {
        return __('plugins.generic.ojsbrJatsViewer.displayName');
    }

    public function getDescription(): string
    {
        return __('plugins.generic.ojsbrJatsViewer.description');
    }

    /**
     * Show an XML galley.
     *
     * @param array{0: Request, 1: ?Issue, 2: ?Galley, 3: Submission, 4: Publication} $args
     */
    public function viewGalley(string $hookName, array $args): bool
    {
        [$request, $issue, $galley, $submission, $publication] = $args;
        $submissionFile = $galley?->getFile();
        if (!$submissionFile || !in_array($submissionFile->getData('mimetype'), self::XML_MIMETYPES)) {
            return Hook::CONTINUE;
        }

        $dependentFiles = $this->getDependentFiles($submissionFile);
        $urls = $this->getUrls($request, $submission, $publication, $galley, $submissionFile, $dependentFiles);
        $defaultLanguage = strtok((string) $publication->getData('locale'), '_@') ?: '';
        $content = $this->getContent($request, $galley, $submissionFile, $dependentFiles, $urls['dependent'], $defaultLanguage);

        $languages = $content['languages'] ?? [];
        $language = JatsDocument::matchLanguage($request->getUserVar('lang'), $languages)
            ?? JatsDocument::matchLanguage(Locale::getLocale(), $languages)
            ?? ($content['main'] ?? null);
        $part = $language !== null ? ($content['parts'][$language] ?? null) : null;

        $templateMgr = TemplateManager::getManager($request);
        $templateMgr->addStyleSheet(
            'ojsbrJatsViewer',
            $request->getBaseUrl() . '/' . $this->getPluginPath() . '/css/jatsViewer.css',
            ['contexts' => 'frontend']
        );

        $languageLinks = [];
        if ($part) {
            foreach ($languages as $code) {
                $url = $request->url(null, 'article', 'view', $request->getRequestedArgs(), ['lang' => $code]);
                $languageLinks[] = [
                    'code' => $code,
                    'label' => $this->getLanguageName($code),
                    'url' => $url,
                    'current' => $code === $language,
                ];
                if (count($languages) > 1) {
                    $templateMgr->addHeader(
                        'ojsbrJatsViewerAlternate' . $code,
                        '<link rel="alternate" hreflang="' . htmlspecialchars(str_replace('_', '-', $code)) . '" href="' . htmlspecialchars($url) . '">'
                    );
                }
            }
        }

        $templateMgr->assign([
            'issue' => $issue,
            'article' => $submission,
            'galley' => $galley,
            'galleyPublication' => $publication,
            'isLatestPublication' => $submission->getData('currentPublicationId') === $publication->getId(),
            'articleUrl' => $urls['article'],
            'downloadUrl' => $urls['download'],
            'jatsLanguages' => $languageLinks,
            'jatsLanguage' => $language,
            'jatsPart' => $part,
        ]);
        $templateMgr->display($this->getTemplateResource('display.tpl'));

        if ($part) {
            $this->recordUsage($request, $submission, $galley, $submissionFile, $issue);
        }

        return Hook::ABORT;
    }

    /**
     * Every language of the galley, rendered, from the cache when possible.
     *
     * @param SubmissionFile[] $dependentFiles
     * @param array<int, string> $dependentUrls
     *
     * @return array{languages?: string[], main?: string, parts?: array<string, array>}
     */
    protected function getContent(Request $request, Galley $galley, SubmissionFile $submissionFile, array $dependentFiles, array $dependentUrls, string $defaultLanguage): array
    {
        $cache = $this->getCache();
        $key = $this->getCacheKey($request, $submissionFile, $dependentFiles, $dependentUrls, $defaultLanguage);
        $cached = $cache->get($galley->getId(), $key);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $content = $this->render($submissionFile, $dependentFiles, $dependentUrls, $defaultLanguage);
        } catch (\Throwable $e) {
            error_log('ojsbrJatsViewer: galley ' . $galley->getId() . ': ' . $e->getMessage());
            return [];
        }

        // An XML that cannot be shown is remembered too, so it is not read again
        // at each visit; a new file makes a new key.
        $cache->put($galley->getId(), $key, $content);

        return $content;
    }

    /**
     * @param SubmissionFile[] $dependentFiles
     * @param array<int, string> $dependentUrls
     * @param string $defaultLanguage Language of the main article when the XML does not say it
     *
     * @return array{languages?: string[], main?: string, parts?: array<string, array>}
     */
    protected function render(SubmissionFile $submissionFile, array $dependentFiles, array $dependentUrls, string $defaultLanguage): array
    {
        $xml = app()->get('file')->fs->read($submissionFile->getData('path'));
        $document = JatsDocument::fromString($xml);
        if (!$document) {
            error_log('ojsbrJatsViewer: submission file ' . $submissionFile->getId() . ' is not a JATS article.');
            return [];
        }

        $names = [];
        foreach ($dependentFiles as $file) {
            foreach ((array) $file->getData('name') as $name) {
                $name = strtolower(trim((string) $name));
                if ($name !== '') {
                    $names[$name] ??= $dependentUrls[$file->getId()];
                    $names[pathinfo($name, PATHINFO_FILENAME)] ??= $dependentUrls[$file->getId()];
                }
            }
        }
        $document->resolveFiles(static function (string $href) use ($names): ?string {
            $name = strtolower(basename(rawurldecode($href)));
            return $names[$name] ?? $names[pathinfo($name, PATHINFO_FILENAME)] ?? null;
        });

        $languages = $document->getLanguages($defaultLanguage);

        $renderer = new JatsRenderer($this->getStylesheet());
        $parts = [];
        foreach ($languages as $language) {
            $parts[$language] = $renderer->render($document, $language, $this->getLabels($language));
        }

        return [
            'languages' => $languages,
            'main' => $languages[0],
            'parts' => $parts,
        ];
    }

    /**
     * Labels of the text, in the language of the text when the plugin has it.
     *
     * @return array<string, string>
     */
    protected function getLabels(string $language): array
    {
        $locales = $this->getPluginLocales();
        $preferred = self::PREFERRED_LABEL_LOCALES[strtolower($language)] ?? null;
        $locale = ($preferred && in_array($preferred, $locales)) ? $preferred : (JatsDocument::matchLanguage($language, $locales) ?? self::FALLBACK_LOCALE);
        $labels = [];
        foreach (JatsRenderer::LABELS as $name => $key) {
            $labels[$name] = __($key, [], $locale);
        }
        return $labels;
    }

    /**
     * Locales the plugin is translated into, the codes of its locale folders.
     *
     * @return string[]
     */
    protected function getPluginLocales(): array
    {
        $locales = [];
        foreach (scandir($this->getPluginDirectory() . '/locale') ?: [] as $entry) {
            if ($entry[0] !== '.' && is_file($this->getPluginDirectory() . '/locale/' . $entry . '/locale.po')) {
                $locales[] = $entry;
            }
        }
        return $locales;
    }

    /**
     * Name of a language in the language of the interface ("Inglês" for en in pt_BR).
     */
    protected function getLanguageName(string $code): string
    {
        $name = \Locale::getDisplayLanguage(str_replace('_', '-', $code), Locale::getLocale());
        if ($name === '' || strcasecmp($name, $code) === 0) {
            return strtoupper($code);
        }
        return mb_strtoupper(mb_substr($name, 0, 1)) . mb_substr($name, 1);
    }

    /**
     * Images and other files uploaded as dependent files of the galley file.
     *
     * @return SubmissionFile[]
     */
    protected function getDependentFiles(SubmissionFile $submissionFile): array
    {
        return Repo::submissionFile()
            ->getCollector()
            ->filterByAssoc(Application::ASSOC_TYPE_SUBMISSION_FILE, [$submissionFile->getId()])
            ->filterByFileStages([SubmissionFile::SUBMISSION_FILE_DEPENDENT])
            ->includeDependentFiles()
            ->getMany()
            ->values()
            ->all();
    }

    /**
     * @param SubmissionFile[] $dependentFiles
     *
     * @return array{article: string, download: string, dependent: array<int, string>}
     */
    protected function getUrls(Request $request, Submission $submission, Publication $publication, Galley $galley, SubmissionFile $submissionFile, array $dependentFiles): array
    {
        $isLatest = $submission->getData('currentPublicationId') === $publication->getId();
        $version = $isLatest ? [] : ['version', $publication->getId()];

        $dependent = [];
        foreach ($dependentFiles as $file) {
            // The same address the Lens Galley plugin gives to these files.
            $dependent[$file->getId()] = $request->url(null, 'article', 'download', [
                $submission->getBestId(), 'version', $publication->getId(), $galley->getBestGalleyId(), $file->getId(), $file->getLocalizedData('name'),
            ]);
        }

        return [
            'article' => $request->url(null, 'article', 'view', [$submission->getBestId(), ...$version]),
            'download' => $request->url(null, 'article', 'download', [$submission->getBestId(), ...$version, $galley->getBestGalleyId(), $submissionFile->getId()]),
            'dependent' => $dependent,
        ];
    }

    /**
     * Everything the HTML depends on: the galley file, its images and their
     * addresses, the code of the plugin and the address of the site.
     *
     * @param SubmissionFile[] $dependentFiles
     * @param array<int, string> $dependentUrls
     */
    protected function getCacheKey(Request $request, SubmissionFile $submissionFile, array $dependentFiles, array $dependentUrls, string $defaultLanguage): string
    {
        $parts = [
            $this->getCodeSignature(),
            $defaultLanguage,
            $request->getBaseUrl(),
            $submissionFile->getId(),
            $submissionFile->getData('fileId'),
            $submissionFile->getData('updatedAt'),
        ];
        foreach ($dependentFiles as $file) {
            $parts[] = implode('|', [$file->getId(), $file->getData('fileId'), $file->getData('updatedAt'), json_encode($file->getData('name')), $dependentUrls[$file->getId()] ?? '']);
        }
        return sha1(implode("\n", $parts));
    }

    protected function getCodeSignature(): string
    {
        static $signature = null;
        if ($signature === null) {
            $files = [$this->getStylesheet(), __FILE__, __DIR__ . '/classes/JatsRenderer.php', __DIR__ . '/classes/JatsDocument.php'];
            $signature = sha1(implode('', array_map(sha1_file(...), $files)));
            foreach ($this->getPluginLocales() as $locale) {
                $signature = sha1($signature . sha1_file($this->getPluginDirectory() . '/locale/' . $locale . '/locale.po'));
            }
        }
        return $signature;
    }

    public function getCache(): JatsCache
    {
        return new JatsCache(Core::getBaseDir() . '/cache/ojsbrJatsViewer');
    }

    public function getStylesheet(): string
    {
        return $this->getPluginDirectory() . '/xsl/jats2html.xsl';
    }

    protected function getPluginDirectory(): string
    {
        return Core::getBaseDir() . '/' . $this->getPluginPath();
    }

    /**
     * Count the view in the statistics as the download of the galley file, the
     * same as the core does when the file is downloaded: the reader no longer
     * downloads the XML to read it, as with the Lens.
     */
    protected function recordUsage(Request $request, Submission $submission, Galley $galley, SubmissionFile $submissionFile, ?Issue $issue): void
    {
        $assocType = Application::ASSOC_TYPE_SUBMISSION_FILE;
        /** @var GenreDAO $genreDao */
        $genreDao = DAORegistry::getDAO('GenreDAO');
        $genre = $genreDao->getById($submissionFile->getData('genreId'));
        if ($genre && ($genre->getCategory() != Genre::GENRE_CATEGORY_DOCUMENT || $genre->getSupplementary() || $genre->getDependent())) {
            $assocType = Application::ASSOC_TYPE_SUBMISSION_FILE_COUNTER_OTHER;
        }
        event(new UsageEvent($assocType, $request->getContext(), $submission, $galley, $submissionFile, $issue));
    }
}

if (!PKP_STRICT_MODE) {
    class_alias('\APP\plugins\generic\ojsbrJatsViewer\OjsbrJatsViewerPlugin', '\OjsbrJatsViewerPlugin');
}
