//================================================================================
// ARQUIVO: cnp_test_run.prg
// DESCRIÇÃO: Programa principal para testar as funções CNP usando RUN('curl...').
//================================================================================

#include "hbclass.ch"
#include "fileio.ch" 

#define INI_FILE          "cnp_config.ini"

// Declaração das funções do cnp_api_run.prg
EXTERNAL CNP_IniCreate, CNP_TokenGenerate, CNP_ConsultarProduto, CNP_CadastrarProduto, CNP_IniRead, CNP_ExtractJsonValue, CNP_GetTimeStamp

PROCEDURE Main()
    
    // ===========================================================================
    // *** 1. DECLARAÇÃO ESTREITA DE TODAS AS VARIÁVEIS LOCAIS NO TOPO ***
    // ===========================================================================
    LOCAL cClientID     := "5e97e991-dab4-412d-b1e3-b27d87ff6291"
    LOCAL cClientSecret := "3b505d72-8a10-4bdb-ab06-167d3d7de5f3"
    LOCAL cUserCNP      := "elton@cipec.com.br"
    LOCAL cPassCNP      := "Beleza@2010!"              
    LOCAL cGtinTest     := "7899999900971" //7898942589065" // 7909053000162"
    LOCAL cCadNumber    := "00610742000139"  
    
    LOCAL cToken
    LOCAL nExpiryTime
    LOCAL nCurrentTime 
    LOCAL cConsultResultJson 
    LOCAL cProductJson    
    LOCAL hFile 
    // ===========================================================================
    
    SET CENTURY ON
    SET DATE TO ANSI 

    CLS
    ? "========================================================"
    ? "    TESTE API CNP (RUN / cURL) | Ambiente ISO 8859-1    "
    ? "========================================================"
    
    // --- PASSO 1: Configuração Inicial e Criação/Reset do INI ---
    ? "1. Verificando/Gerando arquivo de configuração INI..."
    
    // Substituição de FExists por FOpen
    hFile := FOpen( INI_FILE, FO_READ )
    
    IF hFile <= 0 
        // Arquivo NÃO existe ou erro. Chama a criação.
        IF CNP_IniCreate( cClientID, cClientSecret, cUserCNP, cPassCNP )
            ? "   [OK] Arquivo '" + INI_FILE + "' criado com configurações iniciais."
        ELSE
            ? "   [ERRO] Não foi possível criar o arquivo INI."
            RETURN
        ENDIF
    ELSE
        // Arquivo existe. Fecha-o imediatamente.
        FClose( hFile ) 
        ? "   [OK] Arquivo '" + INI_FILE + "' já existe. Mantendo configurações."
    ENDIF

    nCurrentTime := CNP_GetTimeStamp() 


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
            ? "   [FALHA] Não foi possível gerar o token. Verifique as credenciais."
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
        ? "   [FALHA] Consulta de produto falhou."
    ENDIF

    // --- PASSO 4: Cadastro de Produto (Simulação Simplificada) ---
    ?
    ? "4. Cadastrando Novo Produto (Simulação Simplificada)..."
    
    cProductJson := '{' + ;
                     '"company": {' + ;
                        '"cad": "' + cCadNumber + '"' + ; 
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
