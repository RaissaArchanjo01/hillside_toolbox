function relatorio = validar_mde(mde)
    % VALIDAR_MDE Verifica a qualidade e integridade do MDE
    %
    % Sintaxe:
    %   relatorio = geom.utils.validar_mde(mde)
    %
    % Entrada:
    %   mde - Matriz do modelo digital de elevação
    %
    % Saída:
    %   relatorio - Struct com resultado da validação
    %
    % Exemplo:
    %   relatorio = geom.utils.validar_mde(mde);
    
    fprintf('\n╔══════════════════════════════════════════════╗\n');
    fprintf('║         VALIDAÇÃO DO MODELO DIGITAL         ║\n');
    fprintf('║            DE ELEVAÇÃO (MDE)                ║\n');
    fprintf('╚══════════════════════════════════════════════╝\n\n');
    
    % Inicializar relatório
    relatorio = struct();
    relatorio.valido = true;
    relatorio.avisos = {};
    relatorio.erros = {};
    
    % 1. Verificar tipo de dados
    fprintf('1. TIPO DE DADOS\n');
    if ~isnumeric(mde)
        relatorio.erros{end+1} = 'MDE não é numérico';
        relatorio.valido = false;
        fprintf('   ✗ MDE não é numérico\n');
    else
        fprintf('   ✓ MDE é numérico\n');
    end
    
    % 2. Verificar dimensões
    fprintf('\n2. DIMENSÕES\n');
    if ndims(mde) ~= 2
        relatorio.erros{end+1} = 'MDE não é 2D';
        relatorio.valido = false;
        fprintf('   ✗ MDE não é 2D\n');
    else
        fprintf('   ✓ MDE é 2D: %d x %d pixels\n', size(mde, 1), size(mde, 2));
    end
    
    % 3. Verificar valores faltantes
    fprintf('\n3. VALORES FALTANTES (NaN)\n');
    n_nan = sum(isnan(mde(:)));
    perc_nan = 100 * n_nan / numel(mde);
    
    if n_nan > 0
        if perc_nan > 10
            relatorio.erros{end+1} = sprintf('Muitos NaN: %.1f%%', perc_nan);
            relatorio.valido = false;
            fprintf('   ✗ Muitos valores NaN: %d (%.1f%%)\n', n_nan, perc_nan);
        else
            relatorio.avisos{end+1} = sprintf('Alguns NaN: %.1f%%', perc_nan);
            fprintf('   ⚠ Alguns valores NaN: %d (%.1f%%)\n', n_nan, perc_nan);
        end
    else
        fprintf('   ✓ Sem valores NaN\n');
    end
    
    % 4. Verificar valores infinitos
    fprintf('\n4. VALORES INFINITOS\n');
    n_inf = sum(isinf(mde(:)));
    
    if n_inf > 0
        relatorio.erros{end+1} = sprintf('Valores infinitos detectados: %d', n_inf);
        relatorio.valido = false;
        fprintf('   ✗ Valores infinitos detectados: %d\n', n_inf);
    else
        fprintf('   ✓ Sem valores infinitos\n');
    end
    
    % 5. Estatísticas básicas
    fprintf('\n5. ESTATÍSTICAS\n');
    mde_valido = mde(isfinite(mde));
    
    if ~isempty(mde_valido)
        fprintf('   Mínimo:        %.2f m\n', min(mde_valido));
        fprintf('   Máximo:        %.2f m\n', max(mde_valido));
        fprintf('   Média:         %.2f m\n', mean(mde_valido));
        fprintf('   Desvio Padrão: %.2f m\n', std(mde_valido));
        
        relatorio.min = min(mde_valido);
        relatorio.max = max(mde_valido);
        relatorio.media = mean(mde_valido);
        relatorio.desvio = std(mde_valido);
    end
    
    % 6. Verificar depressões
    fprintf('\n6. DETECÇÃO DE DEPRESSÕES\n');
    % Uma depressão é um ponto cercado por pontos mais altos
    kernel = [1 1 1; 1 0 1; 1 1 1];
    
    % Comparar cada pixel com vizinhos
    depressoes = zeros(size(mde));
    for i = 2:size(mde, 1)-1
        for j = 2:size(mde, 2)-1
            if isfinite(mde(i, j))
                vizinhos = [mde(i-1,j-1) mde(i-1,j) mde(i-1,j+1) ...
                           mde(i,j-1)             mde(i,j+1) ...
                           mde(i+1,j-1) mde(i+1,j) mde(i+1,j+1)];
                
                vizinhos_validos = vizinhos(isfinite(vizinhos));
                
                if ~isempty(vizinhos_validos) && mde(i,j) < min(vizinhos_validos)
                    depressoes(i, j) = 1;
                end
            end
        end
    end
    
    n_depressoes = sum(depressoes(:));
    
    if n_depressoes > size(mde, 1)*size(mde, 2)*0.01
        relatorio.avisos{end+1} = sprintf('Muitas depressões detectadas: %d', n_depressoes);
        fprintf('    Muitas depressões detectadas: %d\n', n_depressoes);
        fprintf('     (Considere preencher depressões antes da análise)\n');
    else
        fprintf('   ✓ Número normal de depressões: %d\n', n_depressoes);
    end
    
    % 7. Verificar resolução
    fprintf('\n7. ANÁLISE DE RESOLUÇÃO\n');
    tamanho_total = size(mde, 1) * size(mde, 2);
    
    if tamanho_total < 100*100
        relatorio.avisos{end+1} = 'Resolução muito baixa (< 10000 pixels)';
        fprintf('   ⚠ Resolução muito baixa (< 10000 pixels)\n');
    elseif tamanho_total > 5000*5000
        relatorio.avisos{end+1} = 'MDE muito grande (pode ser lento)';
        fprintf('   ⚠ MDE muito grande (>25M pixels)\n');
    else
        fprintf('   ✓ Resolução adequada: %d pixels\n', tamanho_total);
    end
    
    % 8. Resumo final
    fprintf('\n╔══════════════════════════════════════════════╗\n');
    
    if relatorio.valido && isempty(relatorio.avisos)
        fprintf('║   ✓ MDE VALIDADO COM SUCESSO!              ║\n');
        fprintf('║     Pronto para análise geomorfológica      ║\n');
    elseif relatorio.valido && ~isempty(relatorio.avisos)
        fprintf('║   ✓ MDE VÁLIDO COM AVISOS                  ║\n');
        fprintf('║     Análise possível, mas considere         ║\n');
        fprintf('║     os avisos acima                         ║\n');
    else
        fprintf('║   ✗ MDE COM PROBLEMAS CRÍTICOS             ║\n');
        fprintf('║     Resolva os erros antes de continuar     ║\n');
    end
    
    fprintf('╚══════════════════════════════════════════════╝\n\n');
    
end