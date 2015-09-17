all: gui

gui:
	ocamlbuild -use-ocamlfind gui.native

puz:
	ocamlbuild -use-ocamlfind -I lib plugins/puz/puz.native

clean:
	ocamlbuild -clean
