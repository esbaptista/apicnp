//================================================================================
// ARQUIVO: cnp_test_run.prg
// DESCRIÇÃO: Programa principal para testar as funções CNP usando RUN('curl...').
// DADOS: DADOS E GTIN DO CLIENTE INSERIDOS.
//================================================================================

#include "hbclass.ch"

#define INI_FILE          "cnp_config.ini"

// Declaração das funções do cnp_api_run.prg
EXTERNAL CNP_IniCreate, CNP_TokenGenerate, CNP_ConsultarProduto, CNP_CadastrarProduto, CNP_IniRead, CNP_ExtractJsonValue, CNP_GetTimeStamp

PROCEDURE Main()
    
    // ===========================================================================
    // *** 1. DADOS DE ACESSO E GTIN FORNECIDOS ***
    // ===========================================================================
    LOCAL cClientID     := "5e97e991-dab4-412d-b1e3-b27d87ff6291"
    LOCAL cClientSecret := "3b505d72-8a10-4bdb-ab06-167d3d7de5f3"
    LOCAL cUserCNP      := "elton@cipec.com.br"
    LOCAL cPassCNP      := "Beleza@2010!"              
    // GTIN de consulta (o primeiro da sua lista)
    LOCAL cGtinTest     := "7909053000162"
    
    // Outros GTINs fornecidos (para referência):
    // 7909053000223, 7909053002999, 7909053003293, 7909053003750, 
    // 7909053003903, 7909053004153, 7909053004382, 7909053004641, 7909053004771
    // Altere o cGtinTest acima para testar outros.
    // ===========================================================================
    
    LOCAL cToken
    LOCAL nExpiryTime
    LOCAL nCurrentTime := CNP_GetTimeStamp()
    LOCAL cConsultResultJson := ""
    LOCAL cProductJson       := ""

    SET CENTURY ON
    SET DATE TO ANSI // Garante formato yyyy.mm.dd

    CLS
    ? "========================================================"
    ? "    TESTE API CNP (RUN / cURL) | Ambiente ISO 8859-1    "
    ? "========================================================"
    
    // --- PASSO 1: Configuração Inicial e Criação/Reset do INI ---
    ? "1. Gerando arquivo de configuração INI..."
    IF CNP_IniCreate( cClientID, cClientSecret, cUserCNP, cPassCNP )
        ? "   [OK] Arquivo '" + INI_FILE + "' criado/atualizado."
    ELSE
        ? "   [ERRO] Não foi possível criar/atualizar o arquivo INI."
        RETURN
    ENDIF

    // --- PASSO 2: Verificação e Geração do Token ---
    ?
    ? "2. Solicitando Token de Acesso (Duração: 3h)..."
    
    cToken = CNP_IniRead( "TOKEN", "ACCESS_TOKEN" )
    nExpiryTime = Val( CNP_IniRead( "TOKEN", "EXPIRY_TIME" ) )
    
    IF Empty( cToken ) .OR. nCurrentTime >= nExpiryTime
        ? "   [INFO] Token expirado ou não existente. Solicitando novo token..."
        cToken := CNP_TokenGenerate()
        
        IF ! Empty( cToken )
            ? "   [OK] Token Gerado com SUCESSO. (Salvo em: " + INI_FILE + ")"
        ELSE
            ? "   [FALHA] Não foi possível gerar o token. Verifique as credenciais e o ambiente cURL."
            RETURN
        ENDIF
    ELSE
        ? "   [OK] Token Válido (Salvo no INI)."
    ENDIF
    
    // --- PASSO 3: Consulta de Produto ---
    ?
    ? "3. Consultando Produto (GTIN: " + cGtinTest + ")..."
    cConsultResultJson := CNP_ConsultarProduto( cGtinTest )
    
    IF ! Empty( cConsultResultJson )
        ? "   [OK] Consulta bem-sucedida."
        ? "   Resposta JSON Recebida (ISO 8859-1): (Apenas uma amostra da string)"
        ? Substr( cConsultResultJson, 1, 100 ) + "..."
        
        ? "   GTIN Status Code: " + CNP_ExtractJsonValue( cConsultResultJson, "gtinStatusCode" )
    ELSE
        ? "   [FALHA] Consulta de produto falhou. (Pode ser 404 - GTIN não encontrado ou outro erro)"
    ENDIF

    // --- PASSO 4: Cadastro de Produto (Simulação Simplificada) ---
    ?
    ? "4. Cadastrando Novo Produto (Simulação Simplificada)..."
    
    // ATENÇÃO: SUBSTITUA 'SEU_NUMERO_CAD_AQUI' PELO CAD (CNPJ) CORRETO DA SUA EMPRESA.
    cProductJson := '{' + ;
                     '"company": {' + ;
                        '"cad": "SEU_NUMERO_CAD_AQUI"' + ; 
                     '},' + ;
                     '"gtinStatusCode": "INACTIVE",' + ;
                     '"gs1TradeItemIdentificationKey": {' + ;
                        '"gs1TradeItemIdentificationKeyCode": "GTIN_13"' + ;
                     '},' + ;
                     '"tradeItemDescriptionInformationLang": [' + ;
                         '{ "tradeItemDescription" : "PROD TESTE RUN ' + DToC( Date() ) + '", ' + ;
                           '"languageCode" : "pt-BR", "default" : true }' + ;
                     ']' + ;
                   '}'

    ? "   JSON de Envio: " + cProductJson

    IF CNP_CadastrarProduto( cProductJson )
        ? "   [OK] Função de Cadastro executada."
    ELSE
        ? "   [FALHA] Cadastro de produto falhou."
    ENDIF
    
    ?
    ? "========================================================"
    ? "             FIM DO PROGRAMA DE TESTE                   "
    ? "========================================================"

RETURN
