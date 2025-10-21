//================================================================================
// ARQUIVO: cnp_api_run.prg
// DESCRIÇÃO: Funções da API CNP usando RUN('curl...').
// CORREÇÃO FINAL: Substituição de MEMOLINECOUNT/MEMOLINE por RAt() e Substr().
//================================================================================

#include "hbclass.ch"
#include "fileio.ch" 

// --- CONFIGURAÇÕES GLOBAIS ---
#DEFINE CNP_HOST_HML      "https://api-hml.gs1br.org"
#DEFINE INI_FILE          "cnp_config.ini"
#DEFINE RESPONSE_FILE     "/tmp/cnp_response.txt"
#DEFINE BODY_FILE         "/tmp/cnp_body.json"
#DEFINE TIMESTAMP_FILE    "/tmp/cnp_timestamp.tmp"
#DEFINE CONV_INPUT_FILE   "/tmp/cnp_conv_in.tmp"  
#DEFINE CONV_OUTPUT_FILE  "/tmp/cnp_conv_out.tmp" 

// --------------------------------------------------------------------------------
// FUNÇÕES DE UTILIDADE (INI, JSON, Base64 e Codificação)
// --------------------------------------------------------------------------------

// Implementação manual de leitura INI
FUNCTION CNP_IniRead( cSection, cKey )
    LOCAL cContent := MemoRead( INI_FILE )
    LOCAL cValue := ""
    LOCAL nSectionPos := 0
    LOCAL nKeyPos := 0
    LOCAL nEndLine := 0
    
    nSectionPos := At( "[" + cSection + "]" + CHR(10), cContent )

    IF nSectionPos > 0
        nKeyPos := At( CHR(10) + cKey + "=", cContent, nSectionPos )
        
        IF nKeyPos > 0
            nKeyPos += Len( CHR(10) + cKey + "=" )
            nEndLine := At( CHR(10), cContent, nKeyPos )
            
            IF nEndLine > 0
                cValue := Substr( cContent, nKeyPos, nEndLine - nKeyPos )
            ELSE
                cValue := Substr( cContent, nKeyPos )
            ENDIF
        ENDIF
    ENDIF
    
    RETURN Alltrim( cValue )

// Implementação manual de escrita INI
FUNCTION CNP_IniWrite( cSection, cKey, cValue )
    LOCAL cContent := MemoRead( INI_FILE )
    LOCAL cNewContent := ""
    LOCAL nSectionPos := 0
    LOCAL nKeyPos := 0
    LOCAL nEndLine := 0
    LOCAL cNewKeyLine := cKey + "=" + cValue
    LOCAL hFile
    LOCAL lSuccess := .F.

    nSectionPos := At( "[" + cSection + "]" + CHR(10), cContent )

    IF nSectionPos > 0
        nKeyPos := At( CHR(10) + cKey + "=", cContent, nSectionPos )

        IF nKeyPos > 0 
            nKeyPos += Len( CHR(10) ) 
            nEndLine := At( CHR(10), cContent, nKeyPos )
            
            cNewContent := Substr( cContent, 1, nKeyPos - 1 ) + cNewKeyLine + Substr( cContent, nEndLine )
            
        ELSE 
            nSectionPos += Len( "[" + cSection + "]" + CHR(10) )
            
            cNewContent := Substr( cContent, 1, nSectionPos - 1 ) + cNewKeyLine + CHR(10) + Substr( cContent, nSectionPos )
        ENDIF
        
        hFile := FCreate( INI_FILE, FC_NORMAL ) 
        IF hFile > 0
            FWrite( hFile, cNewContent )
            FClose( hFile )
            lSuccess := .T.
        ENDIF
    ENDIF

    RETURN lSuccess

// Cria ou reseta o arquivo INI
FUNCTION CNP_IniCreate( cClientID, cClientSecret, cUser, cPassword )
    LOCAL aIniContent := {}
    LOCAL hFile
    LOCAL cContent := "" 
    LOCAL cLine
    
    AAdd( aIniContent, "[CONFIG]" )
    AAdd( aIniContent, "HOST=" + CNP_HOST_HML ) 
    AAdd( aIniContent, "CLIENT_ID=" + cClientID )
    AAdd( aIniContent, "CLIENT_SECRET=" + cClientSecret )
    AAdd( aIniContent, "USERNAME=" + cUser )
    AAdd( aIniContent, "PASSWORD=" + cPassword )
    AAdd( aIniContent, "" )
    AAdd( aIniContent, "[TOKEN]" )
    AAdd( aIniContent, "ACCESS_TOKEN=" )
    AAdd( aIniContent, "EXPIRY_TIME=" ) 
    
    FOR EACH cLine IN aIniContent
        cContent += cLine + CHR(10)
    NEXT
    
    hFile := FCreate( INI_FILE, FC_NORMAL ) 

    IF hFile > 0
        FWrite( hFile, cContent )
        FClose( hFile )
        RETURN .T.
    ENDIF
    RETURN .F.

// Função para obter o Unix Timestamp (via date +%s)
FUNCTION CNP_GetTimeStamp()
    LOCAL cResult
    LOCAL nTimeStamp := 0
    
    RUN( "date +%s > " + TIMESTAMP_FILE )
    cResult := MemoRead( TIMESTAMP_FILE )
    FERASE( TIMESTAMP_FILE )

    nTimeStamp := Val( Alltrim( cResult ) )
    
    RETURN nTimeStamp
    
// Função para extrair valor JSON (estável)
FUNCTION CNP_ExtractJsonValue( cJson, cKey )
    LOCAL nStart, nEnd, cPattern
    
    cPattern := '"' + cKey + '":'
    nStart := At( cPattern, cJson )
    
    IF nStart = 0
        RETURN ""
    ENDIF
    
    nStart += Len( cPattern )
    
    WHILE Substr( cJson, nStart, 1 ) $ " " .OR. Substr( cJson, nStart, 1 ) == '"'
        nStart++
    ENDDO
    
    nEnd := At( '"', cJson, nStart )
    
    IF nEnd = 0
        nEnd := At( ',', cJson, nStart )
        IF nEnd = 0
            nEnd := At( '}', cJson, nStart )
            IF nEnd = 0
                RETURN ""
            ENDIF
        ENDIF
    ENDIF
    
    RETURN Substr( cJson, nStart, nEnd - nStart )

// Substitui HB_Base64Encode por uma chamada shell (base64)
FUNCTION CNP_Base64Encode( cString )
    LOCAL cResult
    
    RUN( "echo -n " + Alltrim( cString ) + " | base64 > " + TIMESTAMP_FILE )
    cResult := MemoRead( TIMESTAMP_FILE )
    FERASE( TIMESTAMP_FILE )

    RETURN Alltrim( cResult )

// Substitui HB_OemToUTF8 por iconv.
FUNCTION CNP_OemToUTF8( cString )
    LOCAL hFile
    LOCAL cResult
    
    hFile := FCreate( CONV_INPUT_FILE, FC_NORMAL )
    IF hFile > 0
        FWrite( hFile, cString )
        FClose( hFile )
        
        RUN( "iconv -f ISO-8859-1 -t UTF-8 < " + CONV_INPUT_FILE + " > " + CONV_OUTPUT_FILE )
        
        cResult := MemoRead( CONV_OUTPUT_FILE )
        FERASE( CONV_INPUT_FILE )
        FERASE( CONV_OUTPUT_FILE )
        RETURN cResult
    ENDIF
    RETURN ""

// Substitui HB_UTF8TOOEM por iconv.
FUNCTION CNP_Utf8ToOem( cString )
    LOCAL hFile
    LOCAL cResult

    hFile := FCreate( CONV_INPUT_FILE, FC_NORMAL )
    IF hFile > 0
        FWrite( hFile, cString )
        FClose( hFile )
        
        RUN( "iconv -f UTF-8 -t ISO-8859-1 < " + CONV_INPUT_FILE + " > " + CONV_OUTPUT_FILE )
        
        cResult := MemoRead( CONV_OUTPUT_FILE )
        FERASE( CONV_INPUT_FILE )
        FERASE( CONV_OUTPUT_FILE )
        RETURN cResult
    ENDIF
    RETURN ""

// --------------------------------------------------------------------------------
// FUNÇÃO UTILITÁRIA DE CURL (RUN)
// --------------------------------------------------------------------------------

STATIC FUNCTION CNP_CurlExecute( cUrl, cMethod, aHeaders, cBody_ISO8859_1 )
    LOCAL cCurlCommand  := "curl -s -k" 
    LOCAL cHeaderCommand := ""
    LOCAL cResponse     := ""
    LOCAL nHttpCode     := 0
    LOCAL lSuccess      := .F.
    LOCAL hFile
    LOCAL cHeader
    
    FOR EACH cHeader IN aHeaders
        cHeaderCommand += ' -H "' + cHeader + '"'
    NEXT
    cCurlCommand += cHeaderCommand
    
    IF Upper( cMethod ) == "POST" .OR. Upper( cMethod ) == "PATCH"
        hFile := FCreate( BODY_FILE, FC_NORMAL )
        IF hFile > 0
            FWrite( hFile, CNP_OemToUTF8( cBody_ISO8859_1 ) )
            FClose( hFile )
            cCurlCommand += ' -X ' + Upper( cMethod ) + ' -d @' + BODY_FILE 
        ELSE
            ALERT( "Erro ao criar arquivo temporário para o Body JSON." )
            RETURN { .F., "", 0 }
        ENDIF
    ELSEIF Upper( cMethod ) == "GET"
        cCurlCommand += ' -X GET'
    ENDIF
    
    cCurlCommand += ' -w "\n%{http_code}" ' + cUrl + ' -o ' + RESPONSE_FILE

    RUN( cCurlCommand )
    
    cResponse := MemoRead( RESPONSE_FILE )
    
    IF Empty( cResponse )
        RETURN { .F., "", 0 }
    ENDIF

    // *** CORRIGIDO: Substitui MemoLineCount/MemoLine por RAt() e Substr() ***
    nLastNLPos := RAt( CHR(10), cResponse ) 
    cHttpCodeStr := ""

    IF nLastNLPos > 0
        // O código HTTP está na última linha (após o último CHR(10))
        cHttpCodeStr := Substr( cResponse, nLastNLPos + 1 )
        nHttpCode = Val( Alltrim( cHttpCodeStr ) )
        
        // Remove o código HTTP e o último CHR(10) da resposta
        cResponse := Substr( cResponse, 1, nLastNLPos - 1 ) 
    ELSE
        // Caso não haja CHR(10) (resposta inesperada)
        nHttpCode = 0
    ENDIF
    // FIM DA CORREÇÃO
    
    // A resposta (cResponse) pode ser HTML (erro) ou JSON (sucesso/falha de negócio)
    cResponse := CNP_Utf8ToOem( cResponse )

    lSuccess := ( nHttpCode >= 200 .AND. nHttpCode < 300 )

    FERASE( RESPONSE_FILE )
    IF Upper( cMethod ) == "POST" .OR. Upper( cMethod ) == "PATCH"
        FERASE( BODY_FILE )
    ENDIF
    
    RETURN { lSuccess, cResponse, nHttpCode }

// ... (código anterior omitido)

// --------------------------------------------------------------------------------
// 1. FUNÇÃO PARA GERAR O TOKEN (FORMATO CORRIGIDO: x-www-form-urlencoded)
// --------------------------------------------------------------------------------

FUNCTION CNP_TokenGenerate()
    // ... (variáveis locais omitidas para brevidade)
    LOCAL cHost         := CNP_IniRead( "CONFIG", "HOST" )
    LOCAL cUrl          := cHost + "/oauth/access-token"
    LOCAL cClientID     := CNP_IniRead( "CONFIG", "CLIENT_ID" )
    LOCAL cClientSecret := CNP_IniRead( "CONFIG", "CLIENT_SECRET" )
    LOCAL cUser         := CNP_IniRead( "CONFIG", "USERNAME" )
    LOCAL cPassword     := CNP_IniRead( "CONFIG", "PASSWORD" )
    LOCAL cAuthBasic    := ""
    LOCAL aHeaders      := {}
    LOCAL cBodyJson     := "" // O nome 'Json' é mantido, mas o conteúdo é FORM-ENCODED
    LOCAL aResult       := {} 
    LOCAL cToken        := ""
    LOCAL nExpiry       := 0

    IF Empty( cClientID ) .OR. Empty( cUser )
        ALERT( "Configure o CLIENT_ID, USERNAME e PASSWORD antes de prosseguir." )
        RETURN ""
    ENDIF

    cAuthBasic := CNP_Base64Encode( cClientID + ":" + cClientSecret )
    AAdd( aHeaders, "Authorization: Basic " + cAuthBasic )

    // *** CORREÇÃO: Formato x-www-form-urlencoded ***
    cBodyJson := 'grant_type=password&' + ;
                 'username=' + cUser + '&' + ;
                 'password=' + cPassword
                 
    AAdd( aHeaders, "Content-type: application/x-www-form-urlencoded" ) // *** CORREÇÃO ***

    aResult := CNP_CurlExecute( cUrl, "POST", aHeaders, cBodyJson )

    IF aResult[ 1 ]
        cToken  := CNP_ExtractJsonValue( aResult[ 2 ], "access_token" )
        nExpiry := Val( CNP_ExtractJsonValue( aResult[ 2 ], "expires_in" ) )

        // ... (resto da função de salvamento do token)
        IF ! Empty( cToken )
            CNP_IniWrite( "TOKEN", "ACCESS_TOKEN", cToken )
            CNP_IniWrite( "TOKEN", "EXPIRY_TIME", Str( CNP_GetTimeStamp() + nExpiry ) )

            RETURN cToken 
        ENDIF
    ENDIF

    ALERT( "ERRO ao gerar o Token. Codigo HTTP: " + Alltrim( Str( aResult[ 3 ] ) ) + Chr( 13 ) + "Resposta: " + aResult[ 2 ] )
    RETURN ""

// --------------------------------------------------------------------------------
// 2. FUNÇÃO PARA CONSULTAR O CNP/PRODUTO
// --------------------------------------------------------------------------------

FUNCTION CNP_ConsultarProduto( cGtin )
    LOCAL cToken    := CNP_IniRead( "TOKEN", "ACCESS_TOKEN" )
    LOCAL cHost     := CNP_IniRead( "CONFIG", "HOST" )
    LOCAL cGtin14   := PadL( cGtin, 14, "0" )
    LOCAL cUrl      := cHost + "/gs1/v2/products/" + cGtin14
    LOCAL aHeaders  := {}
    LOCAL aResult   := {}
    LOCAL cClientID     := CNP_IniRead( "CONFIG", "CLIENT_ID" )
    LOCAL cClientSecret := CNP_IniRead( "CONFIG", "CLIENT_SECRET" )
    LOCAL cAuthBasic    := ""

    IF Empty( cToken )
        ALERT( "Token de acesso não encontrado. Gere o token primeiro." )
        RETURN ""
    ENDIF
    
    cAuthBasic := CNP_Base64Encode( cClientID + ":" + cClientSecret )
    AAdd( aHeaders, "Authorization: Basic " + cAuthBasic )
    AAdd( aHeaders, "access_token: " + cToken ) 
    AAdd( aHeaders, "Content-type: application/json" )

    aResult := CNP_CurlExecute( cUrl, "GET", aHeaders, "" )

    IF aResult[ 1 ]
        RETURN aResult[ 2 ] 
    ELSE
        ALERT( "ERRO ao consultar o GTIN " + cGtin + ". Codigo HTTP: " + Alltrim( Str( aResult[ 3 ] ) ) + Chr( 13 ) + "Resposta: " + aResult[ 2 ] )
        RETURN ""
    ENDIF

// --------------------------------------------------------------------------------
// 3. FUNÇÃO PARA CADASTRAR PRODUTOS NO CNP
// --------------------------------------------------------------------------------

FUNCTION CNP_CadastrarProduto( cProductJson_ISO8859_1 )
    LOCAL cToken    := CNP_IniRead( "TOKEN", "ACCESS_TOKEN" )
    LOCAL cHost     := CNP_IniRead( "CONFIG", "HOST" )
    LOCAL cUrl      := cHost + "/gs1/v2/products"
    LOCAL aHeaders  := {}
    LOCAL aResult   := {}
    LOCAL cClientID     := CNP_IniRead( "CONFIG", "CLIENT_ID" )
    LOCAL cClientSecret := CNP_IniRead( "CONFIG", "CLIENT_SECRET" )
    LOCAL cAuthBasic    := ""

    IF Empty( cToken )
        ALERT( "Token de acesso não encontrado. Gere o token primeiro." )
        RETURN .F.
    ENDIF

    cAuthBasic := CNP_Base64Encode( cClientID + ":" + cClientSecret )
    AAdd( aHeaders, "Authorization: Basic " + cAuthBasic )
    AAdd( aHeaders, "access_token: " + cToken )
    AAdd( aHeaders, "Content-type: application/json" )

    aResult := CNP_CurlExecute( cUrl, "POST", aHeaders, cProductJson_ISO8859_1 )

    IF aResult[ 1 ] 
        ALERT( "Cadastro de Produto realizado com SUCESSO! Codigo HTTP: " + Alltrim( Str( aResult[ 3 ] ) ) + Chr( 13 ) + "Resposta: " + aResult[ 2 ] )
        RETURN .T.
    ELSE
        ALERT( "ERRO ao cadastrar o Produto. Codigo HTTP: " + Alltrim( Str( aResult[ 3 ] ) ) + Chr( 13 ) + "Resposta: " + aResult[ 2 ] )
        RETURN .F.
    ENDIF
