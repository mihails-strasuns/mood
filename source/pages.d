module pages;

import core.vararg;

import vibe.core.log;
import vibe.http.server;
import vibe.templ.diet;
import vibe.stream.memory;

string compileTemplate(string filename, ALIASES...)() {
	auto stream = new MemoryOutputStream;
	compileDietFile!(filename, ALIASES)(stream);
	return cast(string)stream.data; 
}

void wrapPage(string inner, OutputStream output) {
	compileDietFile!("outer.dt", inner)(output);
}
void wrapContent(string title, string content, OutputStream output) {
	wrapPage(compileTemplate!("content.dt", title, content), output);
}