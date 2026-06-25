classdef AnalisadorVertentes
    % ANALISADORVERTENTES Análise de vertentes a partir de MDE
    % Baseado em metodologias de SIGs convencionais
    % 
    % Uso:
    %   analisador = geom.AnalisadorVertentes(mde, resolucao)
    %   [tipo_vertente, classes] = analisador.classificar_vertentes()
    
    properties
        mde              % Modelo Digital de Elevação
        declividade      % Matriz de declividade
        aspecto          % Matriz de aspecto
        curvatura_perfil % Curvatura de perfil
        curvatura_plano  % Curvatura de plano
        resolucao        % Tamanho do pixel (m)
    end
    
    methods
        function obj = AnalisadorVertentes(mde, resolucao)
            % Inicializa o analisador
            % 
            % Entrada:
            %   mde       - Matriz do modelo digital de elevação
            %   resolucao - Tamanho do pixel em metros
            
            obj.mde = double(mde);
            obj.resolucao = resolucao;
            
            % Calcula parâmetros básicos
            obj = obj.calcular_declividade();
            obj = obj.calcular_aspecto();
            obj = obj.calcular_curvatura();
            
            fprintf('✓ Analisador de vertentes criado com sucesso!\n');
            fprintf('  Dimensões do MDE: %d x %d\n', size(obj.mde, 1), size(obj.mde, 2));
            fprintf('  Resolução: %.1f m\n', obj.resolucao);
        end
        
        % ===== MÉTODO 1: Calcular Declividade =====
        function obj = calcular_declividade(obj)
            % Calcula declividade em graus usando diferenças finitas
            
            [fx, fy] = gradient(obj.mde, obj.resolucao);
            obj.declividade = atand(sqrt(fx.^2 + fy.^2));
        end
        
        % ===== MÉTODO 2: Calcular Aspecto =====
        function obj = calcular_aspecto(obj)
            % Aspecto em graus (0-360)
            % 0° = Norte, 90° = Leste, 180° = Sul, 270° = Oeste
            
            [fx, fy] = gradient(obj.mde, obj.resolucao);
            obj.aspecto = atan2d(-fx, fy);
            obj.aspecto(obj.aspecto < 0) = obj.aspecto(obj.aspecto < 0) + 360;
        end
        
        % ===== MÉTODO 3: Curvatura (Perfil e Plano) =====
        function obj = calcular_curvatura(obj)
            % Calcula curvatura de perfil e curvatura de plano
            % Curvatura de perfil: ao longo da direção de máxima declividade
            % Curvatura de plano: perpendicular à direção de máxima declividade
            
            [fy, fx] = gradient(obj.mde, obj.resolucao);
            [fyy, fyx] = gradient(fy, obj.resolucao);
            [fxy, fxx] = gradient(fx, obj.resolucao);
            
            % Curvatura de perfil (profile curvature)
            divisor = obj.resolucao * (fx.^2 + fy.^2).^1.5 + 1e-10;
            obj.curvatura_perfil = (fxx.*fy.^2 - 2*fxy.*fx.*fy + fyy.*fx.^2) / divisor;
            
            % Curvatura de plano (plan curvature)
            divisor2 = obj.resolucao * (fx.^2 + fy.^2) + 1e-10;
            obj.curvatura_plano = -(fxy.*fy.^2 - fyy.*fx.*fy - fxx.*fx.*fy + fxy.*fx.^2) / divisor2;
        end
        
        % ===== MÉTODO 4: Classificar Vertentes =====
        function [tipo_vertente, classes] = classificar_vertentes(obj, limiar_curvatura)
            % Classifica vertentes como convexa, côncava ou retilínea
            % 
            % Entrada:
            %   limiar_curvatura - Valor limite para classificação (default: 0.02)
            % 
            % Saída:
            %   tipo_vertente - Matriz com classificação (1=Convexa, 2=Côncava, 3=Retilínea)
            %   classes       - Cell array com nomes das classes
            
            if nargin < 2
                limiar_curvatura = 0.02;
            end
            
            tipo_vertente = zeros(size(obj.mde));
            
            % Convexa: curvatura de perfil positiva
            tipo_vertente(obj.curvatura_perfil > limiar_curvatura) = 1;
            
            % Côncava: curvatura de perfil negativa
            tipo_vertente(obj.curvatura_perfil < -limiar_curvatura) = 2;
            
            % Retilínea: entre os limiares
            tipo_vertente(abs(obj.curvatura_perfil) <= limiar_curvatura) = 3;
            
            % Nomes das classes
            classes = {'Convexa', 'Côncava', 'Retilínea'};
            
            % Exibir estatísticas
            fprintf('\n=== CLASSIFICAÇÃO DE VERTENTES ===\n');
            fprintf('Convexa:    %.1f%%\n', 100*sum(tipo_vertente(:)==1)/numel(tipo_vertente));
            fprintf('Côncava:    %.1f%%\n', 100*sum(tipo_vertente(:)==2)/numel(tipo_vertente));
            fprintf('Retilínea:  %.1f%%\n', 100*sum(tipo_vertente(:)==3)/numel(tipo_vertente));
        end
        
        % ===== MÉTODO 5: Extrair Limites de Vertentes =====
        function [bordas_convexas, bordas_concavas] = extrair_bordas(obj, limiar)
            % Identifica bordas (cristas e topos de taludes)
            % 
            % Entrada:
            %   limiar - Valor crítico de curvatura (default: 0.05)
            % 
            % Saída:
            %   bordas_convexas - Matriz lógica com cristas
            %   bordas_concavas - Matriz lógica com topos de taludes
            
            if nargin < 2
                limiar = 0.05;
            end
            
            % Convexidade forte (cristas)
            bordas_convexas = obj.curvatura_perfil > limiar;
            
            % Concavidade forte (topos de taludes)
            bordas_concavas = obj.curvatura_perfil < -limiar;
        end
        
        % ===== MÉTODO 6: Comprimento de Vertente =====
        function comprimento = calcular_comprimento_vertente(obj, linha, coluna)
            % Calcula o comprimento da vertente até áreas de baixa declividade
            % Traça o caminho de máxima declividade (flow path)
            % 
            % Entrada:
            %   linha, coluna - Coordenadas iniciais (em pixels)
            % 
            % Saída:
            %   comprimento - Distância em metros
            
            [fx, fy] = gradient(obj.mde, obj.resolucao);
            
            % Normalizar gradientes
            magnitude = sqrt(fx.^2 + fy.^2);
            fx = fx ./ (magnitude + 1e-10);
            fy = fy ./ (magnitude + 1e-10);
            
            % Traçar caminho descendente
            pos_x = coluna;
            pos_y = linha;
            distancia = 0;
            maxiter = 10000;
            iter = 0;
            
            while iter < maxiter
                iter = iter + 1;
                
                % Índices atuais
                ix = round(pos_x);
                iy = round(pos_y);
                
                % Verificar limites
                if ix < 2 || ix > size(obj.mde, 2)-1 || ...
                   iy < 2 || iy > size(obj.mde, 1)-1
                    break;
                end
                
                % Direção do fluxo (descendente)
                dx = -fx(iy, ix);
                dy = -fy(iy, ix);
                
                % Pequeno passo
                passo = obj.resolucao;
                normalizador = sqrt(dx^2 + dy^2) + 1e-10;
                pos_x = pos_x + dx * passo / normalizador;
                pos_y = pos_y + dy * passo / normalizador;
                
                distancia = distancia + obj.resolucao;
                
                % Parar se atingir declividade muito baixa
                mag_atual = magnitude(round(pos_y), round(pos_x));
                if mag_atual < 0.01
                    break;
                end
            end
            
            comprimento = distancia;
        end
        
        % ===== MÉTODO 7: Visualizar =====
        function fig = visualizar_vertentes(obj, tipo_vertente)
            % Cria visualização com 3 painéis
            % 
            % Entrada:
            %   tipo_vertente - Classificação de vertentes
            
            fig = figure('Name', 'Análise de Vertentes', 'Position', [100 100 1400 450]);
            
            % Colormap customizado
            cores_vertentes = [1 0 0;      % Vermelho: Convexa
                              0 0 1;      % Azul: Côncava
                              1 1 0];     % Amarelo: Retilínea
            
            % Subplot 1: MDE
            subplot(1, 3, 1);
            imagesc(obj.mde);
            colorbar;
            colormap(gca, 'gray');
            title('Modelo Digital de Elevação', 'FontSize', 12, 'FontWeight', 'bold');
            axis equal;
            xlabel('Coluna (pixels)');
            ylabel('Linha (pixels)');
            
            % Subplot 2: Curvatura de Perfil
            subplot(1, 3, 2);
            imagesc(obj.curvatura_perfil);
            colormap(gca, 'RdBu');
            cb = colorbar;
            cb.Label.String = 'Curvatura';
            caxis([-max(abs(obj.curvatura_perfil(:))) max(abs(obj.curvatura_perfil(:)))]);
            title('Curvatura de Perfil', 'FontSize', 12, 'FontWeight', 'bold');
            axis equal;
            xlabel('Coluna (pixels)');
            ylabel('Linha (pixels)');
            
            % Subplot 3: Classificação
            subplot(1, 3, 3);
            imagesc(tipo_vertente);
            colormap(gca, cores_vertentes);
            cb = colorbar('Ticks', [1 2 3], 'TickLabels', {'Convexa', 'Côncava', 'Retilínea'});
            title('Classificação de Vertentes', 'FontSize', 12, 'FontWeight', 'bold');
            axis equal;
            xlabel('Coluna (pixels)');
            ylabel('Linha (pixels)');
            
            % Suptitle
            sgtitle('Análise Geomorfológica de Vertentes', 'FontSize', 14, 'FontWeight', 'bold');
        end
        
        % ===== MÉTODO 8: Gerar Estatísticas =====
        function stats = gerar_estatisticas(obj, tipo_vertente)
            % Calcula estatísticas gerais da análise
            % 
            % Saída:
            %   stats - Struct com várias métricas
            
            stats.n_pixels_total = numel(obj.mde);
            stats.n_convexa = sum(tipo_vertente(:)==1);
            stats.n_concava = sum(tipo_vertente(:)==2);
            stats.n_retilinea = sum(tipo_vertente(:)==3);
            
            stats.perc_convexa = 100 * stats.n_convexa / stats.n_pixels_total;
            stats.perc_concava = 100 * stats.n_concava / stats.n_pixels_total;
            stats.perc_retilinea = 100 * stats.n_retilinea / stats.n_pixels_total;
            
            stats.declividade_media = mean(obj.declividade(:));
            stats.declividade_max = max(obj.declividade(:));
            stats.declividade_min = min(obj.declividade(:));
            
            stats.curvatura_media = mean(obj.curvatura_perfil(:));
            
            % Exibir relatório
            fprintf('\n');
            fprintf('╔════════════════════════════════════════╗\n');
            fprintf('║     RELATÓRIO DE ANÁLISE DE VERTENTES     ║\n');
            fprintf('╚════════════════════════════════════════╝\n');
            fprintf('Pixels Convexos:    %7d (%.1f%%)\n', stats.n_convexa, stats.perc_convexa);
            fprintf('Pixels Côncavos:    %7d (%.1f%%)\n', stats.n_concava, stats.perc_concava);
            fprintf('Pixels Retilíneos:  %7d (%.1f%%)\n', stats.n_retilinea, stats.perc_retilinea);
            fprintf('\nDeclividade:\n');
            fprintf('  Média:   %.2f°\n', stats.declividade_media);
            fprintf('  Máxima:  %.2f°\n', stats.declividade_max);
            fprintf('  Mínima:  %.2f°\n', stats.declividade_min);
            fprintf('\nCurvatura de Perfil:\n');
            fprintf('  Média:   %.6f\n', stats.curvatura_media);
            fprintf('════════════════════════════════════════\n\n');
        end
    end
end