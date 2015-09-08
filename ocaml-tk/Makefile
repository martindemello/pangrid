all: gui

gui:
	ocamlbuild -use-ocamlfind gui.native

native:
	ocamlbuild -use-ocamlfind varix.native
	cp -L varix.native varix

profile:
	ocamlbuild -use-ocamlfind varix.p.native

clean:
	ocamlbuild -clean
