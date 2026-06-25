function [mde, info] = carregar_mde(caminho_arquivo)
    % CARREGAR_MDE Carrega arquivo de MDE em diferentes formatos
    %
    % Sintaxe:
    %   [mde, info] = geom.carregar_mde(caminho)
    %
    % Entrada:
    %   caminho_arquivo - Caminho do arquivo (.tif, .mat, .asc, .img)
    %
    % Saída:
    %   mde  - Matriz com os dados de elevação
    %   info - Struct com metadados (opcional)
    %
    % Exemplos:
    %   [mde, info] = geom.carregar_mde('C:\dados\mde.tif');
    %   [mde, ~] = geom.carregar_mde('mde.mat');
    
    % Verificar se arquivo existe
    if ~isfile(caminho_arquivo)
        error('Arquivo não encontrado: %s', caminho_arquivo);
    end
    
    % Obter extensão
    [~, ~, ext] = fileparts(caminho_arquivo);
    ext = lower(ext);
    
    fprintf('Carregando MDE: %s\n', caminho_arquivo);
    
    switch ext
        case '.tif'
            % GeoTIFF
            try
                mde = readgeoraster(caminho_arquivo);
                info = geotiffinfo(caminho_arquivo);
                fprintf('✓ GeoTIFF carregado com sucesso\n');
            catch
                warning('Não foi possível ler georeferência. Carregando como imagem comum.');
                mde = imread(caminho_arquivo);
                info = struct();
            end
            
        case '.mat'
            % MATLAB
            dados = load(caminho_arquivo);
            
            % Procurar por variável de MDE
            campos = fieldnames(dados);
            if length(campos) == 1
                mde = dados.(campos{1});
            else
                % Se tiver múltiplas variáveis, procurar por padrão comum
                possibilidades = {'mde', 'MDE', 'dem', 'DEM', 'elevation', 'z'};
                encontrado = false;
                
                for i = 1:length(possibilidades)
                    if isfield(dados, possibilidades{i})
                        mde = dados.(possibilidades{i});
                        encontrado = true;
                        break;
                    end
                end
                
                if ~encontrado
                    error('Arquivo .mat contém múltiplas variáveis. Especifique qual é o MDE.');
                end
            end
            
            info = struct('formato', '.mat');
            fprintf('✓ Arquivo MATLAB carregado com sucesso\n');
            
        case '.asc'
            % ASCII Grid (ESRI)
            fid = fopen(caminho_arquivo, 'r');
            header = struct();
            
            % Ler cabeçalho
            for i = 1:6
                linha = fgetl(fid);
                partes = strsplit(linha);
                header.(partes{1}) = str2double(partes{2});
            end
            
            % Ler dados
            mde = fscanf(fid, '%f', [header.ncols, header.nrows])';
            fclose(fid);
            
            info = header;
            fprintf('✓ ASCII Grid carregado com sucesso\n');
            
        case '.img'
            % ERDAS Imagine
            try
                mde = imread(caminho_arquivo);
                info = imfinfo(caminho_arquivo);
                fprintf('✓ Arquivo ERDAS Imagine carregado com sucesso\n');
            catch
                error('Erro ao carregar arquivo ERDAS Imagine');
            end
            
        otherwise
            error('Formato não suportado: %s', ext);
    end
    
    % Converter para double
    mde = double(mde);
    
    % Informações gerais
    fprintf('\nInformações do MDE:\n');
    fprintf('  Tamanho:      %d x %d pixels\n', size(mde, 1), size(mde, 2));
    fprintf('  Elevação min: %.2f m\n', min(mde(:)));
    fprintf('  Elevação max: %.2f m\n', max(mde(:)));
    fprintf('  Elevação mé:  %.2f m\n', mean(mde(:)));
    fprintf('  NaN values:   %d\n\n', sum(isnan(mde(:))));
    
end