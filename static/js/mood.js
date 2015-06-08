(function () {

	var $ = function (el, sel) {
		if (sel) {
			return el.querySelector(sel);
		}
		else {
			return document.querySelector(el);
		}
	};
	var $$ = function (el, sel) {
		if (sel) {
			return el.querySelectorAll(sel);
		}
		else {
			return document.querySelectorAll(el);
		}
	};
	
	var on = function (element, event, handler) {
		element.addEventListener(event, handler);
	};
	
	var post = function (url, data, cb) {
		var request = new XMLHttpRequest();
		request.open('POST', url, true);
		request.setRequestHeader('Content-Type', 'application/json');
		request.send(JSON.stringify(data));
		request.onload = function() {
			if (request.status >= 200 && request.status < 400) {
				cb(JSON.parse(request.responseText));
			}
		};
	};
	
	var init = [

		['post', function () {
			
			var form = $('.NewEntry form');
			on(form, 'submit', function (e) {
				e.preventDefault();
				post('/post', {
					title: $(form, '[name=title]').value,
					content: $(form, '[name=content]').value
				}, function (res) {
					location.href = res.url;
				});
			});
			
		}]

	];

	on(window, 'load', function () {
	
		var i;
		var loc = document.location.pathname;
		for (i = 0; i < init.length; i++) {
			if (loc.match('^\\/' + init[i][0])) {
				init[i][1]();
				break;
			}
		}
		
	});
	
})();