talk:
	if lsof -i :4333 | grep ruby; then \
		echo 'already running'; \
	else \
		deck slides.md & \
		sleep 2; \
	fi

html: talk dist assets
	# TODO: The -b option isn't really done yet:
	# it gives bad paths to css/js/etc assets
	# and doesn't run CodeRay first.
	# Easier to just fire up the server
	# and copy from View Source.
	# deck -b slides.md

	curl http://localhost:4333 > dist/slides.html
	perl -p -i -e 's#/deck.js#deck.js#g' dist/slides.html
	perl -p -i -e 's#/coderay.css#coderay.css#g' dist/slides.html
	perl -p -i -e 's#/tables.css#tables.css#g' dist/slides.html
	perl -p -i -e 's#/toc.css#toc.css#g' dist/slides.html

dist:
	mkdir -p dist

assets: dist
	cp -r `bundle show deckrb`/public/* dist/

.PHONY: assets html talk

