class_name UiIcons
extends RefCounted

## Ícones vetoriais artesanais da UI (#119, #250), desenhados em estilo cartoon/cel-shaded do
## ScanDig (grade 32 x 32, silhueta externa firme em tinta INK #2B2118, traços internos mais finos
## e volumes em 2-3 tons de luz/sombra) e rasterizados em alta definição (HiDPI 3x com Lanczos +
## set_size_override) para manter nitidez real em 720p, 1080p e 1440p sem alterar métricas de layout.

const INK: String = "#2B2118"
## Contorno externo principal (silhueta comic firme) e traço interno mais delicado (dobras/detalhes).
const OUT_STROKE: String = "stroke=\"#2B2118\" stroke-width=\"2.15\" stroke-linejoin=\"round\" stroke-linecap=\"round\""
const IN_STROKE: String = "stroke=\"#2B2118\" stroke-width=\"1.3\" stroke-linejoin=\"round\" stroke-linecap=\"round\""
const WOOD_STROKE: String = "stroke=\"#5C3B22\" stroke-width=\"1.25\" stroke-linejoin=\"round\" stroke-linecap=\"round\""

## Corpo de cada ícone dentro de <svg viewBox="0 0 32 32">:
## {o} = contorno externo INK 2.15px, {i} = detalhe interno INK 1.3px, {w} = detalhe sépia/madeira.
const SHAPES: Dictionary = {
	# Mochila de lona e couro com rolo de acampamento e fivelas de latão.
	"backpack": "<path d=\"M11.5 7.5 C11.5 4.2 20.5 4.2 20.5 7.5\" fill=\"none\" {o}/>"
		+ "<rect x=\"7\" y=\"5.8\" width=\"18\" height=\"4.4\" rx=\"2.2\" fill=\"#DFCFA8\" {o}/>"
		+ "<rect x=\"6\" y=\"9\" width=\"20\" height=\"18.5\" rx=\"5\" fill=\"#C87D3B\" {o}/>"
		+ "<path d=\"M19 9.8 H21.5 A3.5 3.5 0 0 1 25 13.3 V22.5 A4 4 0 0 1 21 26.5 H16.5 Z\" fill=\"#9E5B24\"/>"
		+ "<path d=\"M6.2 10.5 Q16 16.2 25.8 10.5 L25.5 14.2 Q16 18.8 6.5 14.2 Z\" fill=\"#D9924C\" {i}/>"
		+ "<rect x=\"10\" y=\"18.5\" width=\"12\" height=\"6.5\" rx=\"2\" fill=\"#9E5B24\" {i}/>"
		+ "<rect x=\"10.2\" y=\"9.2\" width=\"2.6\" height=\"11\" rx=\"0.8\" fill=\"#5C3B22\" {i}/>"
		+ "<rect x=\"19.2\" y=\"9.2\" width=\"2.6\" height=\"11\" rx=\"0.8\" fill=\"#5C3B22\" {i}/>"
		+ "<rect x=\"9.8\" y=\"14.5\" width=\"3.4\" height=\"2.6\" rx=\"0.6\" fill=\"#F2C65A\" {i}/>"
		+ "<rect x=\"18.8\" y=\"14.5\" width=\"3.4\" height=\"2.6\" rx=\"0.6\" fill=\"#F2C65A\" {i}/>",

	# Dobrao de ouro chanfrado em 3D com espessura lateral e brilho diagonal.
	"coin": "<circle cx=\"17\" cy=\"17\" r=\"11.2\" fill=\"#A87012\" {o}/>"
		+ "<circle cx=\"15.2\" cy=\"15.2\" r=\"11.2\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M8.5 9.2 A9.5 9.5 0 0 1 21.5 8.8\" fill=\"none\" stroke=\"#FFF5C2\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"15.2\" cy=\"15.2\" r=\"7.6\" fill=\"#E0A526\" stroke=\"#8A5A10\" stroke-width=\"1.3\"/>"
		+ "<path d=\"M15.2 10.2 L18.2 15.2 L15.2 20.2 L12.2 15.2 Z\" fill=\"#FFF2B2\" stroke=\"#7A4E0D\" stroke-width=\"1.2\" stroke-linejoin=\"round\"/>",

	# Caveira expressiva estilo quadrinhos com sombra de zigoma e dentes esculpidos.
	"skull": "<path d=\"M16 4.2 C8.6 4.2 5.2 9 5.2 14.2 C5.2 17.6 7 19.8 9.4 20.9 V25.2 Q9.4 27.2 11.4 27.2 H20.6 Q22.6 27.2 22.6 25.2 V20.9 C25 19.8 26.8 17.6 26.8 14.2 C26.8 9 23.4 4.2 16 4.2 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M21.5 6.8 C24.2 9 25.6 11.6 25.6 14.4 C25.6 17.4 24 19.3 21.4 20.4 V25.8 H17.5 V21.2 C20.5 20 22.2 17.2 22.2 13.5 C22.2 10.8 21.8 8.5 21.5 6.8 Z\" fill=\"#DFCFA8\"/>"
		+ "<path d=\"M16 4.2 C8.6 4.2 5.2 9 5.2 14.2 C5.2 17.6 7 19.8 9.4 20.9 V25.2 Q9.4 27.2 11.4 27.2 H20.6 Q22.6 27.2 22.6 25.2 V20.9 C25 19.8 26.8 17.6 26.8 14.2 C26.8 9 23.4 4.2 16 4.2 Z\" fill=\"none\" {o}/>"
		+ "<ellipse cx=\"11.6\" cy=\"14.8\" rx=\"3\" ry=\"3.3\" transform=\"rotate(-8 11.6 14.8)\" fill=\"#2B2118\"/>"
		+ "<ellipse cx=\"20.4\" cy=\"14.8\" rx=\"3\" ry=\"3.3\" transform=\"rotate(8 20.4 14.8)\" fill=\"#2B2118\"/>"
		+ "<path d=\"M16 17.6 L14.4 20.6 H17.6 Z\" fill=\"#2B2118\"/>"
		+ "<path d=\"M13.4 23.2 V26.8 M16 23.2 V26.8 M18.6 23.2 V26.8\" {i}/>",

	# Coracao rubi cel-shaded com crescente de sombra e brilho especular.
	"heart": "<path d=\"M16 27.4 C8.2 21.6 4 17.2 4 11.8 C4 7.8 7 5 10.6 5 C13.1 5 14.9 6.3 16 8.4 C17.1 6.3 18.9 5 21.4 5 C25 5 28 7.8 28 11.8 C28 17.2 23.8 21.6 16 27.4 Z\" fill=\"#E04B3A\" {o}/>"
		+ "<path d=\"M21.8 6 C24.8 6.4 26.8 8.8 26.8 12 C26.8 16.8 22.8 20.9 16 26.2 C19.8 21.2 22.4 16.8 22.4 12 C22.4 9.5 22 7.4 21.8 6 Z\" fill=\"#A62B20\"/>"
		+ "<path d=\"M16 27.4 C8.2 21.6 4 17.2 4 11.8 C4 7.8 7 5 10.6 5 C13.1 5 14.9 6.3 16 8.4 C17.1 6.3 18.9 5 21.4 5 C25 5 28 7.8 28 11.8 C28 17.2 23.8 21.6 16 27.4 Z\" fill=\"none\" {o}/>"
		+ "<path d=\"M8.2 10.8 C8.2 8.8 9.8 7.6 11.6 7.8\" fill=\"none\" stroke=\"#FFD9D2\" stroke-width=\"2.3\" stroke-linecap=\"round\"/>",

	# Coxa assada de provisao de campo com osso cruzado e glassado dourado.
	"food": "<path d=\"M18.6 18.6 L25 25\" stroke=\"#2B2118\" stroke-width=\"6.2\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"26.2\" cy=\"23.6\" r=\"2.5\" fill=\"#FAF0D7\" {o}/>"
		+ "<circle cx=\"23.6\" cy=\"26.2\" r=\"2.5\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M18.4 18.4 L24.6 24.6\" stroke=\"#FAF0D7\" stroke-width=\"2.8\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M7.2 7.2 C11.2 3.6 17.8 4.4 20.4 8.8 C22.4 12.2 21.4 16.8 19.2 19 C17 21.2 12.4 22.2 9 20.2 C4.6 17.6 3.6 11.2 7.2 7.2 Z\" fill=\"#CC6E30\" {o}/>"
		+ "<path d=\"M18.5 8.5 C20.8 11.6 20.2 16 18.2 18.2 C16.2 20.2 12.2 20.8 9.2 19.2 C13.4 19.2 17.4 15.8 18.5 8.5 Z\" fill=\"#99481A\"/>"
		+ "<path d=\"M8.8 9.8 Q11.5 7.4 14.8 8.2\" fill=\"none\" stroke=\"#F7BE86\" stroke-width=\"2\" stroke-linecap=\"round\"/>",

	# Chave inglesa forjada em aco de dois tons com canal rebaixado no cabo.
	"wrench": "<path d=\"M20.6 4.5 A6.6 6.6 0 0 0 14.2 13.2 L5.2 22.2 A3 3 0 0 0 9.5 26.5 L18.5 17.5 A6.6 6.6 0 0 0 27.2 11.1 L23.2 13.6 L19.4 12.2 L18 8.4 Z\" fill=\"#C9D4DC\" {o}/>"
		+ "<path d=\"M18.5 17.5 L9.5 26.5 A3 3 0 0 1 6.8 26.2 L16.4 16.6 Z\" fill=\"#8B99A6\"/>"
		+ "<path d=\"M20.6 4.5 A6.6 6.6 0 0 0 14.2 13.2 L5.2 22.2 A3 3 0 0 0 9.5 26.5 L18.5 17.5 A6.6 6.6 0 0 0 27.2 11.1 L23.2 13.6 L19.4 12.2 L18 8.4 Z\" fill=\"none\" {o}/>"
		+ "<line x1=\"9.2\" y1=\"22.5\" x2=\"15.4\" y2=\"16.3\" stroke=\"#6C7A86\" stroke-width=\"2\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"7.6\" cy=\"24.1\" r=\"1.1\" fill=\"#5C6973\"/>",

	# Gema lapidada em facetas com mesa iluminada e pavilhao profundo.
	"gem": "<polygon points=\"9.5,5.2 22.5,5.2 28,12.2 16,27.2 4,12.2\" fill=\"#66CAE0\" {o}/>"
		+ "<polygon points=\"9.5,5.2 22.5,5.2 19.5,12.2 12.5,12.2\" fill=\"#DDFBFF\"/>"
		+ "<polygon points=\"4,12.2 12.5,12.2 16,27.2\" fill=\"#4BB0C7\"/>"
		+ "<polygon points=\"19.5,12.2 28,12.2 16,27.2\" fill=\"#2B7B91\"/>"
		+ "<polygon points=\"12.5,12.2 19.5,12.2 16,27.2\" fill=\"#66CAE0\"/>"
		+ "<path d=\"M4 12.2 H28 M9.5 5.2 L12.5 12.2 L16 27.2 L19.5 12.2 L22.5 5.2\" fill=\"none\" {i}/>"
		+ "<polygon points=\"9.5,5.2 22.5,5.2 28,12.2 16,27.2 4,12.2\" fill=\"none\" {o}/>",

	# Detector de metais do ScanDig: haste inclinada, caixa laranja com mini-radar e bobina concentrica.
	"detector": "<path d=\"M23.5 5 L12.5 21.5\" stroke=\"#2B2118\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M23.5 5 L12.5 21.5\" stroke=\"#B8C4CC\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>"
		+ "<g transform=\"rotate(32 21.5 7.5)\">"
		+ "<rect x=\"17\" y=\"4.2\" width=\"8.6\" height=\"6.2\" rx=\"1.6\" fill=\"#D9772B\" {o}/>"
		+ "<rect x=\"18.8\" y=\"5.6\" width=\"5\" height=\"3.4\" rx=\"0.8\" fill=\"#173A28\"/>"
		+ "<circle cx=\"21.6\" cy=\"7.2\" r=\"1\" fill=\"#7CFF9B\"/>"
		+ "</g>"
		+ "<ellipse cx=\"11.5\" cy=\"24\" rx=\"8.2\" ry=\"4.2\" fill=\"#E0A82E\" {o}/>"
		+ "<ellipse cx=\"11.5\" cy=\"24\" rx=\"4.2\" ry=\"2\" fill=\"#FAF0D7\" {i}/>"
		+ "<path d=\"M21.5 19.5 Q24.5 21.5 23.5 25\" fill=\"none\" stroke=\"#E0A82E\" stroke-width=\"2\" stroke-linecap=\"round\"/>",

	# Fachada classica do Museu com fundo escuro entre colunas caneladas e frontao dourado.
	"museum": "<rect x=\"6.2\" y=\"12.5\" width=\"19.6\" height=\"12\" fill=\"#4A3525\" {i}/>"
		+ "<path d=\"M3.2 12.2 L16 4.2 L28.8 12.2 Z\" fill=\"#E6B038\" {o}/>"
		+ "<path d=\"M7.2 10.8 L16 5.6 L24.8 10.8 Z\" fill=\"#FFF0B8\" stroke=\"#9A6A14\" stroke-width=\"1.1\" stroke-linejoin=\"round\"/>"
		+ "<rect x=\"4.8\" y=\"12\" width=\"22.4\" height=\"2.6\" rx=\"0.6\" fill=\"#FAF0D7\" {o}/>"
		+ "<rect x=\"6.8\" y=\"14.6\" width=\"3.4\" height=\"9.6\" fill=\"#FAF0D7\" {i}/>"
		+ "<rect x=\"14.3\" y=\"14.6\" width=\"3.4\" height=\"9.6\" fill=\"#FAF0D7\" {i}/>"
		+ "<rect x=\"21.8\" y=\"14.6\" width=\"3.4\" height=\"9.6\" fill=\"#DFCFA8\" {i}/>"
		+ "<rect x=\"3.8\" y=\"24.2\" width=\"24.4\" height=\"3.4\" rx=\"1\" fill=\"#DFCFA8\" {o}/>",

	# Sonda Pinpointer portatil com punho laranja estriado e ponta emissora de sinal rubi.
	"pinpointer": "<g transform=\"rotate(-38 16 16)\">"
		+ "<rect x=\"13\" y=\"13\" width=\"6\" height=\"14\" rx=\"2.4\" fill=\"#D9772B\" {o}/>"
		+ "<path d=\"M13.5 17 H18.5 M13.5 20 H18.5 M13.5 23 H18.5\" {i}/>"
		+ "<path d=\"M13.6 13 L14.6 5.8 Q16 4.2 17.4 5.8 L18.4 13 Z\" fill=\"#6B7782\" {o}/>"
		+ "<circle cx=\"16\" cy=\"5.6\" r=\"2\" fill=\"#E04B3A\" {i}/>"
		+ "</g>"
		+ "<path d=\"M6.2 10.5 A6.5 6.5 0 0 1 11.5 5.2 M3.8 8.2 A9.8 9.8 0 0 1 9.2 2.8\" fill=\"none\" stroke=\"#E04B3A\" stroke-width=\"2\" stroke-linecap=\"round\"/>",

	# Pa de escavacao com punho em T de madeira e lamina chanfrada em aco (fiel ao scandig_icon.svg).
	"shovel": "<g transform=\"rotate(40 16 16)\">"
		+ "<rect x=\"11.5\" y=\"3.5\" width=\"9\" height=\"3.4\" rx=\"1.5\" fill=\"#B87E4A\" {o}/>"
		+ "<rect x=\"14.2\" y=\"6.8\" width=\"3.6\" height=\"11.5\" rx=\"1.2\" fill=\"#9A6334\" {o}/>"
		+ "<path d=\"M10.5 17.8 H21.5 L21.2 23.8 Q16 29.2 10.8 23.8 Z\" fill=\"#CFD8E0\" {o}/>"
		+ "<path d=\"M16 18.2 H21.1 L20.8 23.6 Q18.6 26.2 16 26.8 Z\" fill=\"#8E9CA8\"/>"
		+ "<path d=\"M10.5 17.8 H21.5 L21.2 23.8 Q16 29.2 10.8 23.8 Z\" fill=\"none\" {o}/>"
		+ "<line x1=\"16\" y1=\"18\" x2=\"16\" y2=\"24\" stroke=\"#6C7A86\" stroke-width=\"1.3\" stroke-linecap=\"round\"/>"
		+ "</g>",

	# Seta de acao esculpida em marfim e ouro: alto contraste ate sobre o laranja do PrimaryButton!
	"play": "<path d=\"M8.2 5.4 L25.6 16 L8.2 26.6 L11.4 16 Z\" fill=\"#FFF6DC\" {o}/>"
		+ "<path d=\"M11.4 16 L25.6 16 L8.2 26.6 Z\" fill=\"#E5BE5C\"/>"
		+ "<path d=\"M8.2 5.4 L25.6 16 L8.2 26.6 L11.4 16 Z\" fill=\"none\" {o}/>",

	# Estrela-rosa-dos-ventos facetada em ouro e marfim para Novo Jogo / Host.
	"new": "<polygon points=\"16,3.2 19.4,11.8 28.4,12.4 21.4,18 23.6,26.8 16,21.8 8.4,26.8 10.6,18 3.6,12.4 12.6,11.8\" fill=\"#F2C144\" {o}/>"
		+ "<polygon points=\"16,3.2 19.4,11.8 16,16 12.6,11.8\" fill=\"#FFF6CC\"/>"
		+ "<polygon points=\"16,16 28.4,12.4 21.4,18\" fill=\"#C98E18\"/>"
		+ "<polygon points=\"16,16 23.6,26.8 16,21.8\" fill=\"#B87D12\"/>"
		+ "<polygon points=\"16,3.2 19.4,11.8 28.4,12.4 21.4,18 23.6,26.8 16,21.8 8.4,26.8 10.6,18 3.6,12.4 12.6,11.8\" fill=\"none\" {o}/>",

	# Pasta de arquivo de campo com folha de relatorio inclinada saindo de dentro.
	"load": "<path d=\"M4.2 8.2 Q4.2 6 6.4 6 H12.5 L15 8.8 H25.6 Q27.6 8.8 27.6 10.8 V24.5 Q27.6 26.5 25.6 26.5 H6.4 Q4.2 26.5 4.2 24.5 Z\" fill=\"#9E5F28\" {o}/>"
		+ "<g transform=\"rotate(-4 16 14)\">"
		+ "<rect x=\"7.5\" y=\"7.8\" width=\"16.5\" height=\"11\" rx=\"1.2\" fill=\"#FFF6DC\" {i}/>"
		+ "<path d=\"M10.2 11 H19.5 M10.2 13.8 H17\" {w}/>"
		+ "</g>"
		+ "<path d=\"M3.6 13.2 H28.4 L26.6 25.2 Q26.3 26.6 24.8 26.6 H7.2 Q5.7 26.6 5.4 25.2 Z\" fill=\"#D98E46\" {o}/>"
		+ "<path d=\"M5.6 22.8 H26.4 L26 25.2 Q25.8 26 24.8 26 H7.2 Q6.2 26 6 25.2 Z\" fill=\"#B86E2C\"/>"
		+ "<path d=\"M3.6 13.2 H28.4 L26.6 25.2 Q26.3 26.6 24.8 26.6 H7.2 Q5.7 26.6 5.4 25.2 Z\" fill=\"none\" {o}/>",

	# Dupla de exploradores com chapeu/capacete claro (contrasta tanto no botao creme quanto no laranja!).
	"multiplayer": "<circle cx=\"21.5\" cy=\"11.8\" r=\"3.8\" fill=\"#DFCFA8\" {o}/>"
		+ "<path d=\"M15.8 25.8 C15.8 19.6 18.4 17.2 21.8 17.2 C25.2 17.2 28 19.6 28 25.8 Z\" fill=\"#5FA87A\" {o}/>"
		+ "<circle cx=\"11.5\" cy=\"11.2\" r=\"4.3\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M6.2 9.8 Q11.5 5.2 16.8 9.8 Z\" fill=\"#E5BE5C\" {i}/>"
		+ "<path d=\"M4.2 26.4 C4.2 19.4 7.4 16.8 11.5 16.8 C15.6 16.8 18.8 19.4 18.8 26.4 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M8.6 17.4 L11.5 21.5 L14.4 17.4\" fill=\"#D9772B\" {i}/>",

	# Engrenagem mecanica de 6 dentes largos chanfrada em dois tons com anel de bronze e rebites.
	"gear": "<g transform=\"rotate(14 16 16)\">"
		+ "<path d=\"M13.6 3.5 H18.4 L19.3 6.8 L22.2 8.5 L25.5 7.6 L27.9 11.8 L25.5 14.3 L25.5 17.7 L27.9 20.2 L25.5 24.4 L22.2 23.5 L19.3 25.2 L18.4 28.5 H13.6 L12.7 25.2 L9.8 23.5 L6.5 24.4 L4.1 20.2 L6.5 17.7 L6.5 14.3 L4.1 11.8 L6.5 7.6 L9.8 8.5 L12.7 6.8 Z\" fill=\"#B8C4CE\" {o}/>"
		+ "<circle cx=\"16\" cy=\"16\" r=\"7.6\" fill=\"#8997A3\" {i}/>"
		+ "<circle cx=\"16\" cy=\"16\" r=\"5.6\" fill=\"#E0A82E\" {i}/>"
		+ "<circle cx=\"16\" cy=\"16\" r=\"3.1\" fill=\"#FAF0D7\" {o}/>"
		+ "</g>",

	# Portal de madeira entreaberto com luz quente la dentro e seta clara contornada (legivel no vermelho e no creme!).
	"door": "<rect x=\"5.2\" y=\"4.5\" width=\"14.5\" height=\"22.5\" rx=\"1.8\" fill=\"#FFF6DC\" {o}/>"
		+ "<path d=\"M5.8 5.2 L14.8 7.4 V24.8 L5.8 26.6 Z\" fill=\"#B8783E\" {o}/>"
		+ "<line x1=\"10.2\" y1=\"6.4\" x2=\"10.2\" y2=\"25.6\" {w}/>"
		+ "<circle cx=\"12.8\" cy=\"16.2\" r=\"1.2\" fill=\"#F2C65A\"/>"
		+ "<line x1=\"3.5\" y1=\"27\" x2=\"22\" y2=\"27\" {o}/>"
		+ "<path d=\"M17.5 13.8 H22.8 V10.6 L28.4 16 L22.8 21.4 V18.2 H17.5 Z\" fill=\"#FFF6DC\" {o}/>",

	# Lua crescente cel-shaded com crateras suaves e estrela guia.
	"moon": "<path d=\"M20.2 4.6 A11.4 11.4 0 1 0 27 21.4 A8.8 8.8 0 1 1 20.2 4.6 Z\" fill=\"#F5CE5B\" {o}/>"
		+ "<circle cx=\"11.8\" cy=\"13.5\" r=\"1.6\" fill=\"#D9A432\"/>"
		+ "<circle cx=\"14.5\" cy=\"21.2\" r=\"1.2\" fill=\"#D9A432\"/>"
		+ "<path d=\"M24.2 7.2 L25.2 9.6 L27.6 10.6 L25.2 11.6 L24.2 14 L23.2 11.6 L20.8 10.6 L23.2 9.6 Z\" fill=\"#FFF6DC\" {i}/>",

	# Cadeado pesado de latao chanfrado com haste de aco e fechadura.
	"lock": "<path d=\"M10.5 13.5 V9.5 A5.5 5.5 0 0 1 21.5 9.5 V13.5\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"4.8\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M10.5 13.5 V9.5 A5.5 5.5 0 0 1 21.5 9.5 V13.5\" fill=\"none\" stroke=\"#CFD8E0\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"6.5\" y=\"13\" width=\"19\" height=\"14.2\" rx=\"3\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M20.5 13.6 H22.8 A2.2 2.2 0 0 1 25 15.8 V24.4 A2.2 2.2 0 0 1 22.8 26.6 H16.5 Z\" fill=\"#C48B18\"/>"
		+ "<rect x=\"6.5\" y=\"13\" width=\"19\" height=\"14.2\" rx=\"3\" fill=\"none\" {o}/>"
		+ "<circle cx=\"16\" cy=\"18.8\" r=\"2\" fill=\"#2B2118\"/>"
		+ "<path d=\"M16 20.2 V23.4\" stroke=\"#2B2118\" stroke-width=\"2.2\" stroke-linecap=\"round\"/>",

	# Mapa do tesouro em pergaminho dobrado com trilha pontilhada, colina e X carmesim.
	"map": "<polygon points=\"3.8,7.2 11.8,4.8 20.2,7.4 28.2,5 28.2,24.8 20.2,27.2 11.8,24.6 3.8,27\" fill=\"#FAF0D7\" {o}/>"
		+ "<polygon points=\"11.8,4.8 20.2,7.4 20.2,27.2 11.8,24.6\" fill=\"#DFCFA8\"/>"
		+ "<polygon points=\"3.8,7.2 11.8,4.8 20.2,7.4 28.2,5 28.2,24.8 20.2,27.2 11.8,24.6 3.8,27\" fill=\"none\" {o}/>"
		+ "<path d=\"M11.8 5.2 V24.4 M20.2 7.6 V26.8\" fill=\"none\" {w}/>"
		+ "<path d=\"M6.4 19.5 L8.6 15.6 L10.6 19.5\" fill=\"none\" {w}/>"
		+ "<path d=\"M8.5 21.2 Q14.5 19.5 16 15.2 T22.2 13.5\" fill=\"none\" stroke=\"#6E4A2D\" stroke-width=\"1.4\" stroke-dasharray=\"2.2 2.2\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M21.8 16.2 L25.6 20 M25.6 16.2 L21.8 20\" fill=\"none\" stroke=\"#D64232\" stroke-width=\"2.3\" stroke-linecap=\"round\"/>",

	# Calice de trofeu dourado com alcas curvas, reflexo claro e pedestal de mogno.
	"trophy": "<path d=\"M9.5 7.5 H4.8 C4.8 13.8 8.2 15.6 11.2 16.2 M22.5 7.5 H27.2 C27.2 13.8 23.8 15.6 20.8 16.2\" fill=\"none\" {o}/>"
		+ "<path d=\"M9 5 H23 V11.2 C23 17.5 19.5 19.5 16 19.5 C12.5 19.5 9 17.5 9 11.2 Z\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M12 7.2 V12.5 C12 15 13.2 16.8 14.5 17.5\" fill=\"none\" stroke=\"#FFF6CC\" stroke-width=\"2\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"14.2\" y=\"19.5\" width=\"3.6\" height=\"4\" fill=\"#C98E18\" {i}/>"
		+ "<rect x=\"9.5\" y=\"23.2\" width=\"13\" height=\"4.4\" rx=\"1.4\" fill=\"#8A5428\" {o}/>",

	# Tenda de Pesquisa do ScanDig (substitui a casinha generica: lona, bandeirinha laranja e luz interna!).
	"home": "<path d=\"M16 4.2 V8.5\" {o}/>"
		+ "<polygon points=\"16,4.2 22.2,6 16,7.8\" fill=\"#D9772B\" {i}/>"
		+ "<polygon points=\"3.8,25.5 16,8.2 28.2,25.5\" fill=\"#FAF0D7\" {o}/>"
		+ "<polygon points=\"16,8.2 28.2,25.5 19.8,25.5\" fill=\"#DFCFA8\"/>"
		+ "<polygon points=\"11.2,25.5 16,15.2 20.8,25.5\" fill=\"#4A321F\" {i}/>"
		+ "<polygon points=\"13.6,25.5 16,19.2 18.4,25.5\" fill=\"#F5C856\"/>"
		+ "<polygon points=\"3.8,25.5 16,8.2 28.2,25.5\" fill=\"none\" {o}/>"
		+ "<line x1=\"2.8\" y1=\"25.8\" x2=\"29.2\" y2=\"25.8\" {o}/>",

	# Nuvem carregada em duas camadas e gotas de chuva inclinadas.
	"rain": "<path d=\"M8.2 19.2 H23.5 A4.6 4.6 0 0 0 24.2 10.2 A6.6 6.6 0 0 0 11.4 9 A5 5 0 0 0 8.2 19.2 Z\" fill=\"#9EB0BD\" {o}/>"
		+ "<path d=\"M8.6 16.8 H23.8 A3.2 3.2 0 0 1 22.8 19 H8.6 Z\" fill=\"#788B99\"/>"
		+ "<path d=\"M8.2 19.2 H23.5 A4.6 4.6 0 0 0 24.2 10.2 A6.6 6.6 0 0 0 11.4 9 A5 5 0 0 0 8.2 19.2 Z\" fill=\"none\" {o}/>"
		+ "<path d=\"M11 22.2 L9 27 M16.5 22.2 L14.5 27 M22 22.2 L20 27\" fill=\"none\" stroke=\"#5AC2DA\" stroke-width=\"2.4\" stroke-linecap=\"round\"/>",

	# Cristal de neve de 6 pontas com ramificacoes e nucleo celeste.
	"snow": "<path d=\"M16 3.8 V28.2 M5.4 9.9 L26.6 22.1 M26.6 9.9 L5.4 22.1\" stroke=\"#2B2118\" stroke-width=\"4\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M16 3.8 V28.2 M5.4 9.9 L26.6 22.1 M26.6 9.9 L5.4 22.1\" stroke=\"#D6F3FC\" stroke-width=\"2\" stroke-linecap=\"round\"/>"
		+ "<polygon points=\"16,11.8 19.6,13.9 19.6,18.1 16,20.2 12.4,18.1 12.4,13.9\" fill=\"#AEE6F8\" {i}/>",

	# Nuvem vulcanica de cinzas com brasas incandescentes.
	"ash": "<path d=\"M7.8 18.8 H23.5 A4.6 4.6 0 0 0 24 9.8 A6.4 6.4 0 0 0 11.2 8.8 A5 5 0 0 0 7.8 18.8 Z\" fill=\"#9E9086\" {o}/>"
		+ "<circle cx=\"10.5\" cy=\"24.2\" r=\"2.1\" fill=\"#E87A2E\" {i}/>"
		+ "<circle cx=\"16.8\" cy=\"26\" r=\"1.8\" fill=\"#F5C84C\" {i}/>"
		+ "<circle cx=\"22.2\" cy=\"23.4\" r=\"2\" fill=\"#E87A2E\" {i}/>",

	# Sol radiante cel-shaded com raios alternados.
	"sun": "<circle cx=\"16\" cy=\"16\" r=\"7\" fill=\"#F5C84C\" {o}/>"
		+ "<path d=\"M12.5 12.2 A4.5 4.5 0 0 1 18.5 11.5\" fill=\"none\" stroke=\"#FFF6CC\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M16 3.2 V6.6 M16 25.4 V28.8 M3.2 16 H6.6 M25.4 16 H28.8 M6.9 6.9 L9.4 9.4 M22.6 22.6 L25.1 25.1 M25.1 6.9 L22.6 9.4 M9.4 22.6 L6.9 25.1\" fill=\"none\" {o}/>",

	# Placa triangular de alerta com borda chanfrada dourada e exclamacao firme.
	"warning": "<path d=\"M16 4.2 L28.4 25.6 Q29.2 27.2 27.4 27.2 H4.6 Q2.8 27.2 3.6 25.6 Z\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M16 8.2 L25 24.4 H7 Z\" fill=\"#FFE27A\" stroke=\"#B57E14\" stroke-width=\"1.1\" stroke-linejoin=\"round\"/>"
		+ "<path d=\"M16 12.4 V18.8\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"2.8\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"16\" cy=\"22.4\" r=\"1.6\" fill=\"#2B2118\"/>",

	# Selo verde-garrafa chanfrado com visto claro contornado.
	"check": "<circle cx=\"16\" cy=\"16\" r=\"11.6\" fill=\"#4EA36E\" {o}/>"
		+ "<path d=\"M23.5 8.5 A10.5 10.5 0 0 1 8.5 23.5 A10.5 10.5 0 0 0 23.5 8.5 Z\" fill=\"#2F6B4A\"/>"
		+ "<circle cx=\"16\" cy=\"16\" r=\"11.6\" fill=\"none\" {o}/>"
		+ "<path d=\"M10.2 16.4 L14.2 20.4 L22.2 11.8\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"4.8\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		+ "<path d=\"M10.2 16.4 L14.2 20.4 L22.2 11.8\" fill=\"none\" stroke=\"#FAF0D7\" stroke-width=\"2.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>",

	# Duas fichas de anotacao sobrepostas com canto dobrado.
	"copy": "<rect x=\"10\" y=\"4.2\" width=\"16\" height=\"19\" rx=\"2.2\" fill=\"#DFCFA8\" {o}/>"
		+ "<path d=\"M6 8.5 H19 L23 12.5 V27.2 H6 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M19 8.5 V12.5 H23\" fill=\"#DFCFA8\" {i}/>"
		+ "<path d=\"M9.5 15.2 H18.5 M9.5 19 H18.5 M9.5 22.8 H15.5\" fill=\"none\" {w}/>",

	# Lampada de filamento de latao com brilho quente interno.
	"bulb": "<path d=\"M16 3.8 C10.8 3.8 7.2 7.4 7.2 12.2 C7.2 15.5 9.2 17.8 11.2 19.8 V22.5 H20.8 V19.8 C22.8 17.8 24.8 15.5 24.8 12.2 C24.8 7.4 21.2 3.8 16 3.8 Z\" fill=\"#F5CE5B\" {o}/>"
		+ "<circle cx=\"15\" cy=\"11.5\" r=\"4.5\" fill=\"#FFF4B8\"/>"
		+ "<path d=\"M13.5 22.2 V16.2 Q16 14 18.5 16.2 V22.2\" fill=\"none\" stroke=\"#9A6A14\" stroke-width=\"1.4\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"11.6\" y=\"22.5\" width=\"8.8\" height=\"5\" rx=\"1.4\" fill=\"#AEB8C2\" {o}/>"
		+ "<line x1=\"12\" y1=\"25\" x2=\"20\" y2=\"25\" {i}/>",

	# Bussola de bolso em latao com mostrador claro e agulha norte-sul inclinada.
	"compass": "<circle cx=\"16\" cy=\"16.8\" r=\"11.2\" fill=\"#E6B038\" {o}/>"
		+ "<circle cx=\"16\" cy=\"16.8\" r=\"8.4\" fill=\"#FAF0D7\" {i}/>"
		+ "<path d=\"M16 3.2 A2.2 2.2 0 1 1 15.99 3.2\" fill=\"none\" {i}/>"
		+ "<g transform=\"rotate(28 16 16.8)\">"
		+ "<polygon points=\"16,9.5 18.6,16.8 13.4,16.8\" fill=\"#D64232\" {i}/>"
		+ "<polygon points=\"16,24.1 18.6,16.8 13.4,16.8\" fill=\"#6B7782\" {i}/>"
		+ "</g>"
		+ "<circle cx=\"16\" cy=\"16.8\" r=\"1.5\" fill=\"#F2C144\" {i}/>",

	# Caderno de campo costurado em couro com paginas arqueadas e fita marcadora carmesim.
	"book": "<rect x=\"3.4\" y=\"6.8\" width=\"25.2\" height=\"19.6\" rx=\"2.4\" fill=\"#9E5B24\" {o}/>"
		+ "<path d=\"M5.2 6.2 Q10.6 4.8 16 6.8 Q21.4 4.8 26.8 6.2 V24.2 Q21.4 22.8 16 24.8 Q10.6 22.8 5.2 24.2 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M16 6.8 V24.8\" fill=\"none\" {i}/>"
		+ "<path d=\"M7.8 10.8 H13.2 M7.8 14.2 H13.2 M7.8 17.6 H12 M18.8 10.8 H24.2 M18.8 14.2 H24.2\" fill=\"none\" {w}/>"
		+ "<polygon points=\"20.2,5.6 23.6,5.6 23.6,13.4 21.9,11.8 20.2,13.4\" fill=\"#D64232\" {i}/>",

	# Corneta de gramofone/alto-falante em latao com ondas acusticas.
	"audio": "<rect x=\"4.2\" y=\"12\" width=\"5.4\" height=\"8\" rx=\"1.4\" fill=\"#9E5B24\" {o}/>"
		+ "<path d=\"M9.2 12.2 L18.4 6 V26 L9.2 19.8 Z\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M22 11.2 A6.8 6.8 0 0 1 22 20.8 M25.2 7.8 A11.2 11.2 0 0 1 25.2 24.2\" fill=\"none\" {o}/>",

	# Monitor/visor emoldurado com horizonte desenhado na tela.
	"display": "<rect x=\"3.8\" y=\"5\" width=\"24.4\" height=\"17\" rx=\"2.6\" fill=\"#AEB8C2\" {o}/>"
		+ "<rect x=\"6.6\" y=\"7.8\" width=\"18.8\" height=\"11.4\" rx=\"1.2\" fill=\"#FAF0D7\" {i}/>"
		+ "<path d=\"M7 16.5 Q12 13.5 16.5 16.2 T25 15.4 V19 H7 Z\" fill=\"#DFCFA8\"/>"
		+ "<circle cx=\"21.5\" cy=\"11\" r=\"1.6\" fill=\"#F2C144\"/>"
		+ "<path d=\"M16 22 V26.6 M10.5 26.8 H21.5\" fill=\"none\" {o}/>",

	# Lixeira de lata clara contornada em INK para botoes destrutivos (Apagar slot).
	"trash": "<path d=\"M12.2 6.8 V4.8 Q12.2 3.6 13.6 3.6 H18.4 Q19.8 3.6 19.8 4.8 V6.8\" fill=\"none\" {o}/>"
		+ "<rect x=\"5.6\" y=\"6.6\" width=\"20.8\" height=\"3.4\" rx=\"1.4\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M7.6 10 H24.4 L22.8 26.2 Q22.6 27.6 21 27.6 H11 Q9.4 27.6 9.2 26.2 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M18.2 10.4 H23.8 L22.4 25.8 Q22.2 27 20.8 27 H16.8 Z\" fill=\"#DFCFA8\"/>"
		+ "<path d=\"M7.6 10 H24.4 L22.8 26.2 Q22.6 27.6 21 27.6 H11 Q9.4 27.6 9.2 26.2 Z\" fill=\"none\" {o}/>"
		+ "<path d=\"M12.4 13.6 L13 23.8 M16 13.6 V23.8 M19.6 13.6 L19 23.8\" fill=\"none\" {i}/>",

	# Colcheias duplas em latao dourado com barra chanfrada para a faixa de Musica.
	"music": "<path d=\"M12.2 22.8 V8.4 L24.6 5.6 V20.2\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"4.6\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		+ "<path d=\"M12.2 11.4 L24.6 8.6\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"4.6\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M12.2 22.8 V8.4 L24.6 5.6 V20.2\" fill=\"none\" stroke=\"#F2C144\" stroke-width=\"2.2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		+ "<path d=\"M12.2 11.4 L24.6 8.6\" fill=\"none\" stroke=\"#FFF0B8\" stroke-width=\"2\" stroke-linecap=\"round\"/>"
		+ "<ellipse cx=\"9.4\" cy=\"23.4\" rx=\"3.8\" ry=\"3\" transform=\"rotate(-16 9.4 23.4)\" fill=\"#F2C144\" {o}/>"
		+ "<ellipse cx=\"21.8\" cy=\"20.8\" rx=\"3.8\" ry=\"3\" transform=\"rotate(-16 21.8 20.8)\" fill=\"#F2C144\" {o}/>",

	# Sino acustico de latao com badalo e ondas de impacto para a faixa de Efeitos Sonoros.
	"sfx": "<path d=\"M14 4.2 A2 2 0 0 1 18 4.2\" fill=\"none\" {o}/>"
		+ "<path d=\"M8.5 19.5 C8.5 12.2 10.6 7.2 16 7.2 C21.4 7.2 23.5 12.2 23.5 19.5 L25.8 22.4 H6.2 Z\" fill=\"#F2C144\" {o}/>"
		+ "<path d=\"M17.5 8 C21.2 9.2 22.8 13.4 22.8 19.4 L24.8 21.8 H18.6 C19.2 15.8 18.8 11.2 17.5 8 Z\" fill=\"#C98E18\"/>"
		+ "<path d=\"M8.5 19.5 C8.5 12.2 10.6 7.2 16 7.2 C21.4 7.2 23.5 12.2 23.5 19.5 L25.8 22.4 H6.2 Z\" fill=\"none\" {o}/>"
		+ "<circle cx=\"16\" cy=\"24.8\" r=\"2.6\" fill=\"#D9772B\" {o}/>"
		+ "<path d=\"M4.4 11.5 A8.5 8.5 0 0 0 4.4 18.5 M27.6 11.5 A8.5 8.5 0 0 1 27.6 18.5\" fill=\"none\" {o}/>",

	# Controle ergonomico cel-shaded com direcional em cruz e botoes de acao para Controles e Vibracao.
	"gamepad": "<path d=\"M8.5 9.2 H23.5 C26.8 9.2 28.6 12.6 27.8 18.6 L26.8 23.8 C26.2 26.2 23.6 26.6 21.8 24.6 L19.2 21.4 H12.8 L10.2 24.6 C8.4 26.6 5.8 26.2 5.2 23.8 L4.2 18.6 C3.4 12.6 5.2 9.2 8.5 9.2 Z\" fill=\"#FAF0D7\" {o}/>"
		+ "<path d=\"M19.2 21.4 L21.8 24.6 C23.6 26.6 26.2 26.2 26.8 23.8 L27.8 18.6 C28.3 14.8 27.4 11.8 25.6 10.2 C25.8 14.8 24.8 18.8 22.2 21.4 Z\" fill=\"#DFCFA8\"/>"
		+ "<path d=\"M8.5 9.2 H23.5 C26.8 9.2 28.6 12.6 27.8 18.6 L26.8 23.8 C26.2 26.2 23.6 26.6 21.8 24.6 L19.2 21.4 H12.8 L10.2 24.6 C8.4 26.6 5.8 26.2 5.2 23.8 L4.2 18.6 C3.4 12.6 5.2 9.2 8.5 9.2 Z\" fill=\"none\" {o}/>"
		+ "<path d=\"M10.4 13.2 V18.4 M7.8 15.8 H13\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"2.5\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"22.4\" cy=\"14.2\" r=\"1.7\" fill=\"#D9772B\" {i}/>"
		+ "<circle cx=\"19.6\" cy=\"17\" r=\"1.7\" fill=\"#4EA36E\" {i}/>",
}

static var _cache: Dictionary = {}


static func has_icon(icon_name: String) -> bool:
	return SHAPES.has(icon_name)


## SVG completo do ícone (testes conferem que rasteriza).
static func svg(icon_name: String) -> String:
	if not SHAPES.has(icon_name):
		return ""
	var body: String = str(SHAPES[icon_name])
	body = body.replace("{o}", OUT_STROKE).replace("{i}", IN_STROKE).replace("{w}", WOOD_STROKE)
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 32\" width=\"32\" height=\"32\">%s</svg>" % body


## Textura do ícone com `side` px lógicos (cache por nome e tamanho), mas rasterizada em HiDPI 3x
## com supersampling Lanczos + set_size_override para nitidez real em 1080p/1440p; null se inválido.
static func get_icon(icon_name: String, side: int = 24) -> Texture2D:
	var key: String = "%s@%d" % [icon_name, side]
	if _cache.has(key):
		return _cache[key]
	var source: String = svg(icon_name)
	if source.is_empty() or side <= 0:
		return null
	var target_px: int = clampi(side * 3, 54, 192)
	var supersample_px: int = target_px * 2
	var image: Image = Image.new()
	if image.load_svg_from_string(source, float(supersample_px) / 32.0) != OK or image.is_empty():
		return null
	image.resize(target_px, target_px, Image.INTERPOLATE_LANCZOS)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(side, side))
	_cache[key] = texture
	return texture
