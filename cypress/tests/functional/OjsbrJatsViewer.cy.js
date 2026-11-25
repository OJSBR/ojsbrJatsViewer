/**
 * @file cypress/tests/functional/OjsbrJatsViewer.cy.js
 *
 * Copyright (c) 2026 OJSBR (https://ojsbr.com)
 * Distributed under the GNU GPL v3. For full terms see the file docs/COPYING.
 *
 * Functional tests of the XML galley page, as a reader sees it: the language
 * selector of a trilingual SciELO article, the tables panel of an article
 * without figures, the images of a galley, the message for a file that is not
 * JATS, the blocked external entity (XXE), and the Lens or the core page back
 * when the plugin is off.
 *
 * The articles are imported with the native import of OJS from
 * cypress/fixtures/import.xml (made by cypress/support/makeImport.php) into
 * Vol. 1 No. 2 (2014) of the data set of PKP's continuous integration.
 *
 * Parameters (--env): contextPath, adminUser, adminPassword (captcha on login
 * must be off for the run). The first test enables the plugin when it is off.
 */

describe('OJSBR JATS Viewer', function() {
	const contextPath = Cypress.env('contextPath') || 'publicknowledge';
	const adminUser = Cypress.env('adminUser') || 'admin';
	const adminPassword = Cypress.env('adminPassword') || 'admin';
	const issueTitle = Cypress.env('issueTitle') || 'Vol. 1 No. 2 (2014)';
	const rowName = 'ojsbrjatsviewerplugin';

	const pageUrl = (path) => '/index.php/' + contextPath + (path ? '/' + path : '');

	const waitJQuery = () => cy.window().its('jQuery.active', {timeout: 60000}).should('eq', 0);

	const request = (options) => cy.window({log: false}).then((win) => cy.request(Object.assign(
		typeof options === 'string' ? {url: options} : options,
		{headers: Object.assign({'User-Agent': win.navigator.userAgent}, (typeof options === 'string' ? {} : options.headers) || {})}
	)));

	const login = (username, password) => {
		cy.clearCookies();
		request(pageUrl('login')).then((response) => {
			const token = /name="csrfToken" value="([^"]+)"/.exec(response.body)[1];
			const action = /<form[^>]*id="login"[^>]*action="([^"]+)"/.exec(response.body)[1];
			request({method: 'POST', url: action, form: true, body: {csrfToken: token, username: username, password: password}, log: false});
		});
		cy.visit(pageUrl('submissions') + '?reload=' + Date.now());
		cy.get('body').then(($body) => {
			if ($body.find('form#login').length) {
				cy.get('form#login input[name="username"]').type(username, {delay: 0});
				cy.get('form#login input[name="password"]').type(password, {delay: 0, log: false});
				cy.get('form#login').submit();
				cy.get('form#login', {timeout: 30000}).should('not.exist');
			}
		});
	};

	const openPluginsTab = () => {
		cy.visit(pageUrl('management/settings/website') + '?reload=' + Date.now() + '#plugins');
		cy.get('button[id="plugins-button"]', {timeout: 60000}).click();
		cy.get('button[id="plugins-button"]').should('have.attr', 'aria-selected', 'true');
		waitJQuery();
	};

	const setPlugin = (enabled) => {
		cy.get('input[id^="select-cell-' + rowName + '-enabled"]', {timeout: 30000}).then(($checkbox) => {
			if ($checkbox.is(':checked') !== enabled) {
				cy.wrap($checkbox).click();
				if (!enabled) {
					// Disabling asks for confirmation.
					cy.get('.pkp_modal_confirmation button.ok, [data-cy="dialog"] button:contains("OK")', {timeout: 10000}).first().click();
				}
				waitJQuery();
			}
		});
		cy.get('input[id^="select-cell-' + rowName + '-enabled"]').should(enabled ? 'be.checked' : 'not.be.checked');
	};

	// The issue of the test articles, as an anonymous reader sees it.
	const openIssue = () => {
		cy.visit(pageUrl('issue/archive') + '?reload=' + Date.now());
		cy.contains('a', issueTitle).click();
	};

	// Address of a galley of a test article, from the table of contents of the issue.
	const galleyUrl = (title, label = 'XML') => {
		openIssue();
		return cy.contains('.obj_article_summary', title).find('a.obj_galley_link').contains(label).invoke('attr', 'href');
	};

	const article = '#ojsbrJats-article';

	// The same address in another language of the text.
	const inLanguage = (url, language) => url + (url.includes('?') ? '&' : '?') + 'lang=' + language;

	it('Enables the plugin and imports the test articles', function() {
		login(adminUser, adminPassword);
		openPluginsTab();
		setPlugin(true);
		openIssue();
		cy.get('body').then(($body) => {
			if (!$body.text().includes('JATS viewer: trilingual article')) {
				cy.exec('php tools/importExport.php NativeImportExportPlugin import plugins/generic/ojsbrJatsViewer/cypress/fixtures/import.xml ' + contextPath + ' ' + adminUser, {timeout: 120000})
					.its('stdout').should('not.match', /Errors occurred|Erros encontrados/);
			}
		});
		openIssue();
		cy.contains('.obj_article_summary', 'JATS viewer: trilingual article');
	});

	it('Shows each language of a trilingual article, with its own address', function() {
		galleyUrl('JATS viewer: trilingual article').then((url) => {
			// Without a choice, the language of the interface (English in PKP's data set) comes first.
			cy.visit(url);
			cy.get('.ojsbrJats-languages a').should('have.length', 3);
			cy.get('.ojsbrJats-languages a[aria-current="page"]').should('have.length', 1);
			cy.get(article).should('have.attr', 'lang', 'en');
			cy.get('link[rel="alternate"][hreflang="es"]').should('exist');

			cy.visit(inLanguage(url, 'pt'));
			cy.get(article).should('have.attr', 'lang', 'pt');
			cy.get('.ojsbrJats-title').should('contain', 'A deferência como premissa');
			cy.get(article).should('contain', 'Considerações finais');

			cy.visit(inLanguage(url, 'en'));
			cy.get(article).should('have.attr', 'lang', 'en');
			cy.get('.ojsbrJats-title').should('contain', 'Deference as a premise');
			cy.get(article).should('contain', 'Final considerations').and('not.contain', 'Considerações finais');
			cy.get('.ojsbrJats-languages a[hreflang="en"]').should('have.attr', 'aria-current', 'page');

			cy.get('.ojsbrJats-languages a[hreflang="es"]').click();
			cy.location('search').should('contain', 'lang=es');
			cy.get('.ojsbrJats-title').should('contain', 'La deferencia como premisa');
			cy.get('.ojsbrJats-refs li').should('have.length.greaterThan', 10);
		});
	});

	it('Has a tables panel, and no figures panel, when the article has only tables', function() {
		galleyUrl('JATS viewer: tables and no figure').then((url) => {
			cy.visit(url);
			cy.get('.ojsbrJats-panel-figures').should('not.exist');
			cy.get('.ojsbrJats-panel-tables summary').should('contain', '2').click();
			cy.get('.ojsbrJats-panel-tables a').first().click();
			cy.location('hash').should('eq', '#j-t1');
			cy.get('#j-t1 table').should('be.visible');
			cy.get('#j-t2 th[colspan="2"]').should('exist');
			cy.get(article + ' math').should('exist');
			cy.get(article + ' a[href^="javascript"]').should('not.exist');
		});
	});

	it('Shows the images of the galley in the text and in the figures panel', function() {
		galleyUrl('JATS viewer: figures and a table').then((url) => {
			// The Portuguese text has a third figure, whose file was not sent.
			cy.visit(inLanguage(url, 'pt'));
			cy.get('.ojsbrJats-panel-figures summary').should('contain', '3');
			cy.get('.ojsbrJats-panel-tables summary').should('contain', '1');
			cy.get('#j-f1 img').should('be.visible').and(($img) => {
				expect($img[0].naturalWidth, 'image loaded').to.be.greaterThan(0);
			});
			cy.get('#j-f3 .ojsbrJats-missing').should('exist');

			cy.visit(inLanguage(url, 'en'));
			cy.get('.ojsbrJats-panel-figures summary').should('contain', '2');
			cy.get('#j-f1-en img').should(($img) => expect($img[0].naturalWidth, 'image loaded').to.be.greaterThan(0));
		});
	});

	it('Shows a message for a file that is not JATS, and reads no file of the server', function() {
		galleyUrl('JATS viewer: files that cannot be shown', 'Invalid XML').then((url) => {
			cy.visit(url);
			cy.get('.ojsbrJats-error a').should('have.attr', 'href').and('contain', '/article/download/');
			cy.get(article).should('not.exist');
		});
		galleyUrl('JATS viewer: files that cannot be shown', 'XXE').then((url) => {
			cy.visit(url);
			cy.get('.ojsbrJats-title').should('have.text', 'Teste XXE: []');
			cy.get('body').should('not.contain', '/bin/bash').and('not.contain', 'files_dir');
			cy.get(article + ' script').should('not.exist');
		});
	});

	it('Gives the page back to the other viewers when it is off', function() {
		login(adminUser, adminPassword);
		openPluginsTab();
		setPlugin(false);
		cy.clearCookies();
		galleyUrl('JATS viewer: trilingual article').then((url) => {
			cy.request(url).its('body').should('not.contain', 'ojsbrJats-article');
		});
		login(adminUser, adminPassword);
		openPluginsTab();
		setPlugin(true);
	});
});
