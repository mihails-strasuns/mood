module types;

import vibe.inet.path;

struct Settings {
	Path path;
}

struct Markdown {
	Path path;
	Path sourcePath;
	string content;
}