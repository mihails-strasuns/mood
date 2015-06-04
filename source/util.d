module util;

import vibe.core.log;
import vibe.core.file;
import vibe.inet.path;

void createDirectoryRecursive(Path path) {
	if (!existsFile(path)) {
		createDirectoryRecursive(path.parentPath);
		createDirectory(path);
	}
}