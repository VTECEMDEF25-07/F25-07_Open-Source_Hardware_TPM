// tpm_types.vh
//
// Date: 11/6/25
//
// General Description:
//	This is a Verilog header file, which defines some TPM constants.
//	It is not complete.
//	See .\TPMCmd\tpm\include\public\TpmTypes.h in the Microsoft Software implementation,
//	as this file is based on that header.

// Table "Definition of TPM_CC Constants" (Part 2: Structures)
`define TPM_CC_FIRST                      32'h0000011F
`define TPM_CC_NV_UndefineSpaceSpecial    32'h0000011F
`define TPM_CC_EvictControl               32'h00000120
`define TPM_CC_HierarchyControl           32'h00000121
`define TPM_CC_NV_UndefineSpace           32'h00000122
`define TPM_CC_ChangeEPS                  32'h00000124
`define TPM_CC_ChangePPS                  32'h00000125
`define TPM_CC_Clear                      32'h00000126
`define TPM_CC_ClearControl               32'h00000127
`define TPM_CC_ClockSet                   32'h00000128
`define TPM_CC_HierarchyChangeAuth        32'h00000129
`define TPM_CC_NV_DefineSpace             32'h0000012A
`define TPM_CC_PCR_Allocate               32'h0000012B
`define TPM_CC_PCR_SetAuthPolicy          32'h0000012C
`define TPM_CC_PP_Commands                32'h0000012D
`define TPM_CC_SetPrimaryPolicy           32'h0000012E
`define TPM_CC_FieldUpgradeStart          32'h0000012F
`define TPM_CC_ClockRateAdjust            32'h00000130
`define TPM_CC_CreatePrimary              32'h00000131
`define TPM_CC_NV_GlobalWriteLock         32'h00000132
`define TPM_CC_GetCommandAuditDigest      32'h00000133
`define TPM_CC_NV_Increment               32'h00000134
`define TPM_CC_NV_SetBits                 32'h00000135
`define TPM_CC_NV_Extend                  32'h00000136
`define TPM_CC_NV_Write                   32'h00000137
`define TPM_CC_NV_WriteLock               32'h00000138
`define TPM_CC_DictionaryAttackLockReset  32'h00000139
`define TPM_CC_DictionaryAttackParameters 32'h0000013A
`define TPM_CC_NV_ChangeAuth              32'h0000013B
`define TPM_CC_PCR_Event                  32'h0000013C
`define TPM_CC_PCR_Reset                  32'h0000013D
`define TPM_CC_SequenceComplete           32'h0000013E
`define TPM_CC_SetAlgorithmSet            32'h0000013F
`define TPM_CC_SetCommandCodeAuditStatus  32'h00000140
`define TPM_CC_FieldUpgradeData           32'h00000141
`define TPM_CC_IncrementalSelfTest        32'h00000142
`define TPM_CC_SelfTest                   32'h00000143
`define TPM_CC_Startup                    32'h00000144
`define TPM_CC_Shutdown                   32'h00000145
`define TPM_CC_StirRandom                 32'h00000146
`define TPM_CC_ActivateCredential         32'h00000147
`define TPM_CC_Certify                    32'h00000148
`define TPM_CC_PolicyNV                   32'h00000149
`define TPM_CC_CertifyCreation            32'h0000014A
`define TPM_CC_Duplicate                  32'h0000014B
`define TPM_CC_GetTime                    32'h0000014C
`define TPM_CC_GetSessionAuditDigest      32'h0000014D
`define TPM_CC_NV_Read                    32'h0000014E
`define TPM_CC_NV_ReadLock                32'h0000014F
`define TPM_CC_ObjectChangeAuth           32'h00000150
`define TPM_CC_PolicySecret               32'h00000151
`define TPM_CC_Rewrap                     32'h00000152
`define TPM_CC_Create                     32'h00000153
`define TPM_CC_ECDH_ZGen                  32'h00000154
`define TPM_CC_HMAC                       32'h00000155
`define TPM_CC_MAC                        32'h00000155
`define TPM_CC_Import                     32'h00000156
`define TPM_CC_Load                       32'h00000157
`define TPM_CC_Quote                      32'h00000158
`define TPM_CC_RSA_Decrypt                32'h00000159
`define TPM_CC_HMAC_Start                 32'h0000015B
`define TPM_CC_MAC_Start                  32'h0000015B
`define TPM_CC_SequenceUpdate             32'h0000015C
`define TPM_CC_Sign                       32'h0000015D
`define TPM_CC_Unseal                     32'h0000015E
`define TPM_CC_PolicySigned               32'h00000160
`define TPM_CC_ContextLoad                32'h00000161
`define TPM_CC_ContextSave                32'h00000162
`define TPM_CC_ECDH_KeyGen                32'h00000163
`define TPM_CC_EncryptDecrypt             32'h00000164
`define TPM_CC_FlushContext               32'h00000165
`define TPM_CC_LoadExternal               32'h00000167
`define TPM_CC_MakeCredential             32'h00000168
`define TPM_CC_NV_ReadPublic              32'h00000169
`define TPM_CC_PolicyAuthorize            32'h0000016A
`define TPM_CC_PolicyAuthValue            32'h0000016B
`define TPM_CC_PolicyCommandCode          32'h0000016C
`define TPM_CC_PolicyCounterTimer         32'h0000016D
`define TPM_CC_PolicyCpHash               32'h0000016E
`define TPM_CC_PolicyLocality             32'h0000016F
`define TPM_CC_PolicyNameHash             32'h00000170
`define TPM_CC_PolicyOR                   32'h00000171
`define TPM_CC_PolicyTicket               32'h00000172
`define TPM_CC_ReadPublic                 32'h00000173
`define TPM_CC_RSA_Encrypt                32'h00000174
`define TPM_CC_StartAuthSession           32'h00000176
`define TPM_CC_VerifySignature            32'h00000177
`define TPM_CC_ECC_Parameters             32'h00000178
`define TPM_CC_FirmwareRead               32'h00000179
`define TPM_CC_GetCapability              32'h0000017A
`define TPM_CC_GetRandom                  32'h0000017B
`define TPM_CC_GetTestResult              32'h0000017C
`define TPM_CC_Hash                       32'h0000017D
`define TPM_CC_PCR_Read                   32'h0000017E
`define TPM_CC_PolicyPCR                  32'h0000017F
`define TPM_CC_PolicyRestart              32'h00000180
`define TPM_CC_ReadClock                  32'h00000181
`define TPM_CC_PCR_Extend                 32'h00000182
`define TPM_CC_PCR_SetAuthValue           32'h00000183
`define TPM_CC_NV_Certify                 32'h00000184
`define TPM_CC_EventSequenceComplete      32'h00000185
`define TPM_CC_HashSequenceStart          32'h00000186
`define TPM_CC_PolicyPhysicalPresence     32'h00000187
`define TPM_CC_PolicyDuplicationSelect    32'h00000188
`define TPM_CC_PolicyGetDigest            32'h00000189
`define TPM_CC_TestParms                  32'h0000018A
`define TPM_CC_Commit                     32'h0000018B
`define TPM_CC_PolicyPassword             32'h0000018C
`define TPM_CC_ZGen_2Phase                32'h0000018D
`define TPM_CC_EC_Ephemeral               32'h0000018E
`define TPM_CC_PolicyNvWritten            32'h0000018F
`define TPM_CC_PolicyTemplate             32'h00000190
`define TPM_CC_CreateLoaded               32'h00000191
`define TPM_CC_PolicyAuthorizeNV          32'h00000192
`define TPM_CC_EncryptDecrypt2            32'h00000193
`define TPM_CC_AC_GetCapability           32'h00000194
`define TPM_CC_AC_Send                    32'h00000195
`define TPM_CC_Policy_AC_SendSelect       32'h00000196
`define TPM_CC_CertifyX509                32'h00000197
`define TPM_CC_ACT_SetTimeout             32'h00000198
`define TPM_CC_ECC_Encrypt                32'h00000199
`define TPM_CC_ECC_Decrypt                32'h0000019A
`define TPM_CC_PolicyCapability           32'h0000019B
`define TPM_CC_PolicyParameters           32'h0000019C
`define TPM_CC_NV_DefineSpace2            32'h0000019D
`define TPM_CC_NV_ReadPublic2             32'h0000019E
`define TPM_CC_SetCapability              32'h0000019F
`define TPM_CC_LAST                       32'h0000019F
`define CC_VEND                           32'h20000000
`define TPM_CC_Vendor_TCG_Test            32'h20000000

// Table "Definition of TPM_ST Constants" (Part 2: Structures)
`define TPM_ST_RSP_COMMAND          16'h00C4
`define TPM_ST_NULL                 16'h8000
`define TPM_ST_NO_SESSIONS          16'h8001
`define TPM_ST_SESSIONS             16'h8002
`define TPM_ST_ATTEST_NV            16'h8014
`define TPM_ST_ATTEST_COMMAND_AUDIT 16'h8015
`define TPM_ST_ATTEST_SESSION_AUDIT 16'h8016
`define TPM_ST_ATTEST_CERTIFY       16'h8017
`define TPM_ST_ATTEST_QUOTE         16'h8018
`define TPM_ST_ATTEST_TIME          16'h8019
`define TPM_ST_ATTEST_CREATION      16'h801A
`define TPM_ST_ATTEST_NV_DIGEST     16'h801C
`define TPM_ST_CREATION             16'h8021
`define TPM_ST_VERIFIED             16'h8022
`define TPM_ST_AUTH_SECRET          16'h8023
`define TPM_ST_HASHCHECK            16'h8024
`define TPM_ST_AUTH_SIGNED          16'h8025
`define TPM_ST_FU_MANIFEST          16'h8029

// Table "Definition of TPM_SU Constants" (Part 2: Structures)
`define TPM_SU_CLEAR   16'h0000
`define TPM_SU_STATE   16'h0001

// Table "Definition of TPM_RC Constants" (Part 2: Structures)
`define TPM_RC_SUCCESS           (32'h000)
`define TPM_RC_BAD_TAG           (32'h01E)
`define RC_VER1                  (32'h100)
`define TPM_RC_INITIALIZE        (RC_VER1 + 32'h000)
`define TPM_RC_FAILURE           (RC_VER1 + 32'h001)
`define TPM_RC_SEQUENCE          (RC_VER1 + 32'h003)
`define TPM_RC_PRIVATE           (RC_VER1 + 32'h00B)
`define TPM_RC_HMAC              (RC_VER1 + 32'h019)
`define TPM_RC_DISABLED          (RC_VER1 + 32'h020)
`define TPM_RC_EXCLUSIVE         (RC_VER1 + 32'h021)
`define TPM_RC_AUTH_TYPE         (RC_VER1 + 32'h024)
`define TPM_RC_AUTH_MISSING      (RC_VER1 + 32'h025)
`define TPM_RC_POLICY            (RC_VER1 + 32'h026)
`define TPM_RC_PCR               (RC_VER1 + 32'h027)
`define TPM_RC_PCR_CHANGED       (RC_VER1 + 32'h028)
`define TPM_RC_UPGRADE           (RC_VER1 + 32'h02D)
`define TPM_RC_TOO_MANY_CONTEXTS (RC_VER1 + 32'h02E)
`define TPM_RC_AUTH_UNAVAILABLE  (RC_VER1 + 32'h02F)
`define TPM_RC_REBOOT            (RC_VER1 + 32'h030)
`define TPM_RC_UNBALANCED        (RC_VER1 + 32'h031)
`define TPM_RC_COMMAND_SIZE      (RC_VER1 + 32'h042)
`define TPM_RC_COMMAND_CODE      (RC_VER1 + 32'h043)
`define TPM_RC_AUTHSIZE          (RC_VER1 + 32'h044)
`define TPM_RC_AUTH_CONTEXT      (RC_VER1 + 32'h045)
`define TPM_RC_NV_RANGE          (RC_VER1 + 32'h046)
`define TPM_RC_NV_SIZE           (RC_VER1 + 32'h047)
`define TPM_RC_NV_LOCKED         (RC_VER1 + 32'h048)
`define TPM_RC_NV_AUTHORIZATION  (RC_VER1 + 32'h049)
`define TPM_RC_NV_UNINITIALIZED  (RC_VER1 + 32'h04A)
`define TPM_RC_NV_SPACE          (RC_VER1 + 32'h04B)
`define TPM_RC_NV_DEFINED        (RC_VER1 + 32'h04C)
`define TPM_RC_BAD_CONTEXT       (RC_VER1 + 32'h050)
`define TPM_RC_CPHASH            (RC_VER1 + 32'h051)
`define TPM_RC_PARENT            (RC_VER1 + 32'h052)
`define TPM_RC_NEEDS_TEST        (RC_VER1 + 32'h053)
`define TPM_RC_NO_RESULT         (RC_VER1 + 32'h054)
`define TPM_RC_SENSITIVE         (RC_VER1 + 32'h055)
`define RC_MAX_FM0               (RC_VER1 + 32'h07F)
`define RC_FMT1                  (32'h080)
`define TPM_RC_ASYMMETRIC        (RC_FMT1 + 32'h001)
`define TPM_RCS_ASYMMETRIC       (RC_FMT1 + 32'h001)
`define TPM_RC_ATTRIBUTES        (RC_FMT1 + 32'h002)
`define TPM_RCS_ATTRIBUTES       (RC_FMT1 + 32'h002)
`define TPM_RC_HASH              (RC_FMT1 + 32'h003)
`define TPM_RCS_HASH             (RC_FMT1 + 32'h003)
`define TPM_RC_VALUE             (RC_FMT1 + 32'h004)
`define TPM_RCS_VALUE            (RC_FMT1 + 32'h004)
`define TPM_RC_HIERARCHY         (RC_FMT1 + 32'h005)
`define TPM_RCS_HIERARCHY        (RC_FMT1 + 32'h005)
`define TPM_RC_KEY_SIZE          (RC_FMT1 + 32'h007)
`define TPM_RCS_KEY_SIZE         (RC_FMT1 + 32'h007)
`define TPM_RC_MGF               (RC_FMT1 + 32'h008)
`define TPM_RCS_MGF              (RC_FMT1 + 32'h008)
`define TPM_RC_MODE              (RC_FMT1 + 32'h009)
`define TPM_RCS_MODE             (RC_FMT1 + 32'h009)
`define TPM_RC_TYPE              (RC_FMT1 + 32'h00A)
`define TPM_RCS_TYPE             (RC_FMT1 + 32'h00A)
`define TPM_RC_HANDLE            (RC_FMT1 + 32'h00B)
`define TPM_RCS_HANDLE           (RC_FMT1 + 32'h00B)
`define TPM_RC_KDF               (RC_FMT1 + 32'h00C)
`define TPM_RCS_KDF              (RC_FMT1 + 32'h00C)
`define TPM_RC_RANGE             (RC_FMT1 + 32'h00D)
`define TPM_RCS_RANGE            (RC_FMT1 + 32'h00D)
`define TPM_RC_AUTH_FAIL         (RC_FMT1 + 32'h00E)
`define TPM_RCS_AUTH_FAIL        (RC_FMT1 + 32'h00E)
`define TPM_RC_NONCE             (RC_FMT1 + 32'h00F)
`define TPM_RCS_NONCE            (RC_FMT1 + 32'h00F)
`define TPM_RC_PP                (RC_FMT1 + 32'h010)
`define TPM_RCS_PP               (RC_FMT1 + 32'h010)
`define TPM_RC_SCHEME            (RC_FMT1 + 32'h012)
`define TPM_RCS_SCHEME           (RC_FMT1 + 32'h012)
`define TPM_RC_SIZE              (RC_FMT1 + 32'h015)
`define TPM_RCS_SIZE             (RC_FMT1 + 32'h015)
`define TPM_RC_SYMMETRIC         (RC_FMT1 + 32'h016)
`define TPM_RCS_SYMMETRIC        (RC_FMT1 + 32'h016)
`define TPM_RC_TAG               (RC_FMT1 + 32'h017)
`define TPM_RCS_TAG              (RC_FMT1 + 32'h017)
`define TPM_RC_SELECTOR          (RC_FMT1 + 32'h018)
`define TPM_RCS_SELECTOR         (RC_FMT1 + 32'h018)
`define TPM_RC_INSUFFICIENT      (RC_FMT1 + 32'h01A)
`define TPM_RCS_INSUFFICIENT     (RC_FMT1 + 32'h01A)
`define TPM_RC_SIGNATURE         (RC_FMT1 + 32'h01B)
`define TPM_RCS_SIGNATURE        (RC_FMT1 + 32'h01B)
`define TPM_RC_KEY               (RC_FMT1 + 32'h01C)
`define TPM_RCS_KEY              (RC_FMT1 + 32'h01C)
`define TPM_RC_POLICY_FAIL       (RC_FMT1 + 32'h01D)
`define TPM_RCS_POLICY_FAIL      (RC_FMT1 + 32'h01D)
`define TPM_RC_INTEGRITY         (RC_FMT1 + 32'h01F)
`define TPM_RCS_INTEGRITY        (RC_FMT1 + 32'h01F)
`define TPM_RC_TICKET            (RC_FMT1 + 32'h020)
`define TPM_RCS_TICKET           (RC_FMT1 + 32'h020)
`define TPM_RC_RESERVED_BITS     (RC_FMT1 + 32'h021)
`define TPM_RCS_RESERVED_BITS    (RC_FMT1 + 32'h021)
`define TPM_RC_BAD_AUTH          (RC_FMT1 + 32'h022)
`define TPM_RCS_BAD_AUTH         (RC_FMT1 + 32'h022)
`define TPM_RC_EXPIRED           (RC_FMT1 + 32'h023)
`define TPM_RCS_EXPIRED          (RC_FMT1 + 32'h023)
`define TPM_RC_POLICY_CC         (RC_FMT1 + 32'h024)
`define TPM_RCS_POLICY_CC        (RC_FMT1 + 32'h024)
`define TPM_RC_BINDING           (RC_FMT1 + 32'h025)
`define TPM_RCS_BINDING          (RC_FMT1 + 32'h025)
`define TPM_RC_CURVE             (RC_FMT1 + 32'h026)
`define TPM_RCS_CURVE            (RC_FMT1 + 32'h026)
`define TPM_RC_ECC_POINT         (RC_FMT1 + 32'h027)
`define TPM_RCS_ECC_POINT        (RC_FMT1 + 32'h027)
`define TPM_RC_FW_LIMITED        (RC_FMT1 + 32'h028)
`define TPM_RC_SVN_LIMITED       (RC_FMT1 + 32'h029)
`define RC_WARN                  (32'h900)
`define TPM_RC_CONTEXT_GAP       (RC_WARN + 32'h001)
`define TPM_RC_OBJECT_MEMORY     (RC_WARN + 32'h002)
`define TPM_RC_SESSION_MEMORY    (RC_WARN + 32'h003)
`define TPM_RC_MEMORY            (RC_WARN + 32'h004)
`define TPM_RC_SESSION_HANDLES   (RC_WARN + 32'h005)
`define TPM_RC_OBJECT_HANDLES    (RC_WARN + 32'h006)
`define TPM_RC_LOCALITY          (RC_WARN + 32'h007)
`define TPM_RC_YIELDED           (RC_WARN + 32'h008)
`define TPM_RC_CANCELED          (RC_WARN + 32'h009)
`define TPM_RC_TESTING           (RC_WARN + 32'h00A)
`define TPM_RC_REFERENCE_H0      (RC_WARN + 32'h010)
`define TPM_RC_REFERENCE_H1      (RC_WARN + 32'h011)
`define TPM_RC_REFERENCE_H2      (RC_WARN + 32'h012)
`define TPM_RC_REFERENCE_H3      (RC_WARN + 32'h013)
`define TPM_RC_REFERENCE_H4      (RC_WARN + 32'h014)
`define TPM_RC_REFERENCE_H5      (RC_WARN + 32'h015)
`define TPM_RC_REFERENCE_H6      (RC_WARN + 32'h016)
`define TPM_RC_REFERENCE_S0      (RC_WARN + 32'h018)
`define TPM_RC_REFERENCE_S1      (RC_WARN + 32'h019)
`define TPM_RC_REFERENCE_S2      (RC_WARN + 32'h01A)
`define TPM_RC_REFERENCE_S3      (RC_WARN + 32'h01B)
`define TPM_RC_REFERENCE_S4      (RC_WARN + 32'h01C)
`define TPM_RC_REFERENCE_S5      (RC_WARN + 32'h01D)
`define TPM_RC_REFERENCE_S6      (RC_WARN + 32'h01E)
`define TPM_RC_NV_RATE           (RC_WARN + 32'h020)
`define TPM_RC_LOCKOUT           (RC_WARN + 32'h021)
`define TPM_RC_RETRY             (RC_WARN + 32'h022)
`define TPM_RC_NV_UNAVAILABLE    (RC_WARN + 32'h023)
`define TPM_RC_NOT_USED          (RC_WARN + 32'h7F)
`define TPM_RC_H                 (32'h000)
`define TPM_RC_P                 (32'h040)
`define TPM_RC_S                 (32'h800)
`define TPM_RC_1                 (32'h100)
`define TPM_RC_2                 (32'h200)
`define TPM_RC_3                 (32'h300)
`define TPM_RC_4                 (32'h400)
`define TPM_RC_5                 (32'h500)
`define TPM_RC_6                 (32'h600)
`define TPM_RC_7                 (32'h700)
`define TPM_RC_8                 (32'h800)
`define TPM_RC_9                 (32'h900)
`define TPM_RC_A                 (32'hA00)
`define TPM_RC_B                 (32'hB00)
`define TPM_RC_C                 (32'hC00)
`define TPM_RC_D                 (32'hD00)
`define TPM_RC_E                 (32'hE00)
`define TPM_RC_F                 (32'hF00)
`define TPM_RC_N_MASK            (32'hF00)

`define	TPM_SPEC_FAMILY		32'h322E3000
`define	TPM_SPEC_LEVEL		16'd00
`define	TPM_SPEC_VERSION	16'd159
`define	TPM_SPEC_YEAR		16'd2019
`define	TPM_SPEC_DAY_OF_YEAR	16'd312