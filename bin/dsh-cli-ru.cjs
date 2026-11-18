'use strict';

const { registerHooks } = require('node:module');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { fileURLToPath, pathToFileURL } = require('node:url');
const messages = Object.entries(require('./dsh-cli-ru.json'));
const modules = pathToFileURL(join(require('node:path').dirname(process.execPath), 'resources', 'app.asar', 'dsh', 'node_modules')).href + '/';
const cliModule = /^(?:@deepseek-ai\/(?:dsh\/lib\/(?:bin|plugin|profile-boot)(?:-[\w-]+)?|(?:dsh-app-boot|dsh-plugin-manager|dsh-acp-app|dsh-sdk-app)\/lib\/index|(?:dsh-headless|dsh-web-app)\/lib\/startup)|commander\/lib\/(?:help|command))\.js$/;

// Локализует известные строки штатного CLI перед загрузкой модуля только в данном процессе.
// Уже отформатированный вывод, потоки дочерних программ и данные пользователя не обрабатываются.
registerHooks({
  load(url, context, nextLoad) {
    const loaded = nextLoad(url, context);
    if (!url.startsWith(modules) || !cliModule.test(url.slice(modules.length))) return loaded;
    let source = loaded.source == null ? readFileSync(fileURLToPath(url), 'utf8') : Buffer.from(loaded.source).toString('utf8');
    for (const [original, translated] of messages) source = source.replaceAll(original, () => translated);
    return { ...loaded, source };
  }
});
