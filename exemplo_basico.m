%% ========================================================================
%  EXEMPLO BÁSICO - ANÁLISE DE VERTENTES COM MATLAB
%  Toolbox de Geomorfologia
%  ========================================================================

clear all; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║  EXEMPLO BÁSICO - ANÁLISE DE VERTENTES                    ║\n');
fprintf('║  Geomorfologia Toolbox para MATLAB                        ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n');

%% PASSO 1: GERAR MDE SINTÉTICO
% (Para usar um MDE real, veja o script "exemplo_com_mde_real.m")

fprintf('\nPASSO 1: Gerando MDE sintético...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Criar grade
[X, Y] = meshgrid(1:100, 1:100);

% MDE com topografia realista
mde_teste = 500 ...                    % Elevation base
    + 100*sin(X/20) ...               % Ondulação N-S
    + 100*cos(Y/20) ...               % Ondulação L-O
    + 30*sin(X/10).*cos(Y/10) ...     % Variação local
    + 20*randn(100, 100);              % Ruído realista

% Suavizar para ser mais realista
mde_teste = imfilter(mde_teste, fspecial('gaussian', 3, 1));

fprintf('✓ MDE sintético criado (100x100 pixels)\n');

%% PASSO 2: VALIDAR MDE

fprintf('\nPASSO 2: Validando MDE...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

relatorio = geom.utils.validar_mde(mde_teste);

%% PASSO 3: CRIAR ANALISADOR

fprintf('PASSO 3: Criando analisador de vertentes...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Parâmetros
resolucao_pixel = 30;  % Tamanho do pixel em metros

% Instanciar objeto analisador
analisador = geom.AnalisadorVertentes(mde_teste, resolucao_pixel);

%% PASSO 4: CLASSIFICAR VERTENTES

fprintf('PASSO 4: Classificando vertentes...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Limiar de curvatura (ajuste conforme necessário)
limiar = 0.02;  % Quanto maior, mais restritivo

[tipo_vertente, classes] = analisador.classificar_vertentes(limiar);

%% PASSO 5: EXTRAIR BORDAS

fprintf('PASSO 5: Extraindo bordas (cristas e topos de taludes)...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

[bordas_convexas, bordas_concavas] = analisador.extrair_bordas(0.05);

fprintf('✓ Bordas convexas (cristas):     %d pixels\n', sum(bordas_convexas(:)));
fprintf('✓ Bordas côncavas (topos talud): %d pixels\n', sum(bordas_concavas(:)));

%% PASSO 6: CALCULAR COMPRIMENTO DE VERTENTE

fprintf('PASSO 6: Calculando comprimento de vertentes...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Calcular para 3 pontos diferentes
pontos_teste = [30 30; 50 50; 70 70];

for i = 1:size(pontos_teste, 1)
    linha = pontos_teste(i, 1);
    coluna = pontos_teste(i, 2);
    compr = analisador.calcular_comprimento_vertente(linha, coluna);
    fprintf('  Ponto (%d, %d): %.1f metros\n', linha, coluna, compr);
end

%% PASSO 7: GERAR ESTATÍSTICAS

fprintf('PASSO 7: Gerando estatísticas...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

stats = analisador.gerar_estatisticas(tipo_vertente);

%% PASSO 8: VISUALIZAR RESULTADOS

fprintf('PASSO 8: Visualizando resultados...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

fig1 = analisador.visualizar_vertentes(tipo_vertente);

%% PASSO 9: VISUALIZAÇÃO ADICIONAL - DECLIVIDADE E ASPECTO

fprintf('PASSO 9: Criando visualizações adicionais...\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

fig2 = figure('Name', 'Parâmetros Geomorfométricos', 'Position', [100 600 1000 400]);

% Declividade
subplot(1, 2, 1);
imagesc(analisador.declividade);
colorbar;
title('Declividade (graus)', 'FontSize', 12, 'FontWeight', 'bold');
axis equal;
xlabel('Coluna (pixels)');
ylabel('Linha (pixels)');

% Aspecto
subplot(1, 2, 2);
imagesc(analisador.aspecto);
colorbar('Ticks', [0 90 180 270 360], 'TickLabels', {'N', 'E', 'S', 'W', 'N'});
title('Aspecto (0°=N, 90°=E, 180°=S, 270°=W)', 'FontSize', 12, 'FontWeight', 'bold');
axis equal;
xlabel('Coluna (pixels)');
ylabel('Linha (pixels)');

sgtitle('Parâmetros Geomorfométricos do Terreno', 'FontSize', 14, 'FontWeight', 'bold');

%% RESUMO FINAL

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║                 ANÁLISE CONCLUÍDA!                        ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

fprintf('Próximos passos:\n');
fprintf('1. Experimente diferentes limiares de curvatura\n');
fprintf('2. Carregue seu próprio MDE com: [mde, info] = geom.carregar_mde(arquivo)\n');
fprintf('3. Salve resultados como GeoTIFF para usar em SIGs\n');
fprintf('4. Veja "exemplo_com_mde_real.m" para análise com dados reais\n\n');

fprintf('Para mais informações, consulte a documentação: help geom.AnalisadorVertentes\n\n');