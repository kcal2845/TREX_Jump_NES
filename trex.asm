	.inesprg 1
	.ineschr 1
	.inesmap 0
	.inesmir 1
  
;-------------------------------------------------- 상수
STATE_GAMETITLE = $00 ; 게임 상태 상수
STATE_GAMING    = $01
STATE_GAMEOVER  = $02

;;;;;;;;;;;;;;
	.bank 0
;-------------------------------------------------- 변수
	.org $0000
; 스프라이트
SprPointerLo 	.db $00
SprPointerHi 	.db $00
SprBufPointerLo .db $00
SprBufPointerHi .db $00
SprNum       	.db $00 ; 스프라이트 갯수
SprX			.db $00
SprY			.db $00

; 배경
BkgStartline    .db $00
BkgPointerLo    .db $00
BkgPointerHi    .db $00

GameState       .db $00 ; 게임 상태 변수
Scroll          .db $00 ; 스크롤
Nametable       .db $00 ; 네임 테이블 번호

; 타이머
Timer           .db $00
prngtimer		.db $00

; T-rex 변수
TrexX      		.db $00
TrexY      		.db $00
TrexYVel      	.db $00
TrexVel      	.db $00

; 선인장 변수
CactusX			.db $00

seed            .db $00 ; 난수
  
;-------------------------------------------------- 프로그램 코드
	.org $C000
;-------------------------------------------------- RESET
RESET:
	SEI
	CLD
	LDX #$40
	STX $4017
	LDX #$FF
	TXS
	INX
	STX $2000
	STX $2001
	STX $4010

	JSR vblankwait
	
; 메모리 초기화
clrmem:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0200, x	
	INX
	BNE clrmem
   
	JSR vblankwait

; 변수 초기화
	LDA #STATE_GAMING
	STA GameState ; 게임 상태 초기화
	
	LDA #$90
	STA TrexY ; 티렉스 위치
	
	LDA #$05
	STA TrexVel ; 티렉스 속도

; 팔레트	
LoadPalettes:
	LDA $2002
	LDA #$3F
	STA $2006
	LDA #$00
	STA $2006
	LDX #$00
LoadPalettesLoop:
	LDA palette, x
	STA $2007
	INX
	CPX #$20            
	BNE LoadPalettesLoop

; 배경
	JSR LoadTitleScreen

; 그래픽 초기화
	LDA #%10010000 ;NMI활성, 스프라이트 패턴 테이블0, 배경 패턴 테이블1
	STA $2000
	
	LDA #%00011110
	STA $2001
	
Forever:
	JMP Forever
	
;-------------------------------------------------- NMI
NMI:
	JSR GameMain
	INC Timer
	RTI	

;-------------------------------------------------- 메인
GameMain:
	LDA GameState
	CMP #STATE_GAMETITLE
	BNE CheckGaming
	JSR GameTitle
	JMP CheckStateDone
CheckGaming:
	LDA GameState
	CMP #STATE_GAMING
	BNE CheckGameOver
	JSR Gaming
	JMP CheckStateDone
CheckGameOver:
	JSR Gameover
CheckStateDone:
	
	RTS

;-------------------------------------------------- 게임 타이틀
GameTitle:
	JSR SprBufReady
	JSR LoadTrex
	JSR SpriteDMA ; 스프라이트 정보 PPU 전송
	
	LDA #%00011110 ; 스프라이트, 배경 활성화
	STA $2001
	
	RTS
;-------------------------------------------------- 게임

Gaming:
	; 컨트롤러 준비
	LDA #$01
	STA $4016
	LDA #$00 
	STA $4016
	; A 버튼 입력 읽기
GamingReadA: 
	LDA $4016
	AND #$01
	BEQ GamingReadADone 
	; A 버튼 눌렸을 경우
	LDA TrexY
	CMP #$90
	BNE GamingReadADone ; 지면에 있으면 점프
	LDA #$0D
	STA TrexYVel ; 점프 (속도 설정)
GamingReadADone:

; 티렉스 물리
Physics:
	LDA TrexY
	SEC 
	SBC TrexYVel
	STA TrexY ; 속도 적용
	
	
	DEC TrexYVel ; 속도 감소
	
GroundCollideCheck:
	LDA TrexY 
	CMP #$90
	BMI PhysicsDone ; 지면보다 낮으면 y좌표 지면으로, 속도 0으로
	LDA #$90
	STA TrexY
	LDA #$00
	STA TrexYVel
PhysicsDone:

; 선인장

CactusMove:
	SEC
	LDA CactusX
	SBC TrexVel
	STA CactusX
CactusDone:

; 충돌 감지
CollideCheckCactus:
	LDA CactusX
	BMI CollideCheckCactusDone
	CMP #$38
	BPL CollideCheckCactusDone ; X 좌표 체크
	LDA TrexY
	CMP #$60
	BMI CollideCheckCactusDone ; Y 좌표 체크
	
	
	LDA #STATE_GAMEOVER
	STA GameState

CollideCheckCactusDone:

; 스프라이트 로드
; 스프라이트 0
; 티렉스 스프라이트	
	JSR SprBufReady
	JSR LoadTrex
	JSR SpriteDMA ; 스프라이트 정보 PPU 전송

; 선인장 스프라이트
	JSR LoadCactus
; 새 스프라이트

; 배경 스크롤
	JSR ScrollBackground
	
	LDA #%00011110 ; 스프라이트, 배경 활성화
	STA $2001
	
	RTS
;-------------------------------------------------- 게임 오버
Gameover:
	JSR SprBufReady
	JSR LoadTrex
	JSR SpriteDMA ; 스프라이트 정보 PPU 전송
	
	LDA #%00011110 ; 스프라이트, 배경 활성화
	STA $2001
	
	RTS
  
;-------------------------------------------------- 그래픽
;vblank 대기
vblankwait:
	BIT $2002
	BPL vblankwait
	RTS
	
; 스프라이트 활성화
SpriteDMA:
	LDA #$00
	STA $2003
	LDA #$02
	STA $4014
	RTS	

; 스프라이트 버퍼 초기화
SprBufReady:
	LDA #$00
	STA SprBufPointerLo
	LDA #$02
	STA SprBufPointerHi
	RTS

; 스프라이트 로드
LoadSprite:
	LDX #$00
	LDY #$00
LoadSpriteLoop:
	; 1번 Y좌표
	LDA [SprPointerLo], y
	CLC
	ADC SprY
	STA [SprBufPointerLo], y
	INY
	; 2번 타일 넘버
	LDA [SprPointerLo], y
	STA [SprBufPointerLo], y
	INY
	; 3번 세팅
	LDA [SprPointerLo], y
	STA [SprBufPointerLo], y
	INY
	; 4번 X좌표
	LDA [SprPointerLo], y
	CLC
	ADC SprX	
	STA [SprBufPointerLo], y
	INY
	
	INX
	CPX SprNum 
	BNE LoadSpriteLoop	
  
	; y만큼 더해서 SprBuf 업데이트
	TYA
	CLC
	ADC SprBufPointerLo
	STA SprBufPointerLo
	LDA SprBufPointerHi
	ADC #$00
	STA SprBufPointerHi
	
	RTS

; 배경 로드
LoadTitleScreen:
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006
	;PPU 준비

	LDA #LOW(titlescreen)
	STA BkgPointerLo
	LDA #HIGH(titlescreen)
	STA BkgPointerHi ; 배경 포인터
  
	LDX #$00
	LDY #$00
LoadTitleScreenLoop:
	CPY #$00
	LDA [BkgPointerLo],y
	STA $2007
  
	INY
	CPY #$00
	BNE LoadTitleScreenLoop
  
	INC BkgPointerHi
	INX
	CPX #$04
	BNE LoadTitleScreenLoop
	
	LDA #LOW(titlescreen)
	STA BkgPointerLo
	LDA #HIGH(titlescreen)
	STA BkgPointerHi ; 배경 포인터
	
	LDX #$00
	LDY #$00
LoadTitleScreenLoop2:
	CPY #$00
	LDA [BkgPointerLo],y
	STA $2007
  
	INY
	CPY #$00
	BNE LoadTitleScreenLoop2
  
	INC BkgPointerHi
	INX
	CPX #$04
	BNE LoadTitleScreenLoop2
  
	RTS

; 스크롤
ScrollBackground:
	LDA #$00
	STA $2006
	STA $2006 ; PPU 주소 레지스터 지움
	
	LDA Scroll
	CLC
	ADC TrexVel
	STA $2005
	STA Scroll
	BCC NametableCheckDone ; 스크롤 화면 전환
	LDA Nametable
	EOR #$01
	STA Nametable 
	
NametableCheckDone:	
	LDA #$00
	STA $2005
	
	LDA #%10010000
	ORA Nametable ; OR연산
	STA $2000
	
	RTS

; 티렉스 스프라이트 로드
LoadTrex:
	LDA TrexX
	STA SprX
	LDA TrexY
	STA SprY
; 머리 로드
LoadHead:
	LDA GameState
	CMP #STATE_GAMEOVER
	BEQ LoadHeadB
	
	LDA #HIGH(trexHeadA)
	STA SprPointerHi
	LDA #LOW(trexHeadA)
	STA SprPointerLo
	LDA #07
	STA SprNum
	JSR LoadSprite
	
	JMP LoadBody
LoadHeadB:
	LDA #HIGH(trexHeadB)
	STA SprPointerHi
	LDA #LOW(trexHeadB)
	STA SprPointerLo
	LDA #07
	STA SprNum
	JSR LoadSprite
; 몸 로드
LoadBody:
	LDA #HIGH(trexBody)
	STA SprPointerHi
	LDA #LOW(trexBody)
	STA SprPointerLo
	LDA #08
	STA SprNum
	JSR LoadSprite
; 다리 로드
LoadLeg:
	LDA GameState
	CMP #STATE_GAMING ; 게임 중이고 점프 중이거나, 게임중이지 않으면 
	BNE LoadLegStop ; 게임 중이지 않으면 다리 멈춤
	LDA TrexY
	CMP #$90
	BNE LoadLegStop ; 점프 중이면 다리 멈춤
	
	LDA Timer
	AND #%00000100
	CMP #%00000100
	BNE LoadLegRunB ; 타이머에 따라 애니메이션
LoadLegRunA:
	LDA #HIGH(trexLegA)
	STA SprPointerHi
	LDA #LOW(trexLegA)
	STA SprPointerLo
	JMP LoadLegRunDone
LoadLegRunB:
	LDA #HIGH(trexLegB)
	STA SprPointerHi
	LDA #LOW(trexLegB)
	STA SprPointerLo
	JMP LoadLegRunDone
LoadLegStop:
	LDA #HIGH(trexLeg)
	STA SprPointerHi
	LDA #LOW(trexLeg)
	STA SprPointerLo
LoadLegRunDone:
	LDA #05
	STA SprNum
	JSR LoadSprite
	
LoadTrexDone:
	RTS
	
LoadCactus:
	LDA CactusX
	SEC
	SBC #$18
	STA SprX
	LDA #$90
	STA SprY
	
	LDA #HIGH(cactusA)
	STA SprPointerHi
	LDA #LOW(cactusA)
	STA SprPointerLo
	LDA #$0E
	STA SprNum
	JSR LoadSprite
	
	RTS

;-------------------------------------------------- 서브 루틴
prng:
	RTS
;;;;;;;;;;;;;;  
  
	.bank 1
	.org $E000
titlescreen:
	;.org $E1A0
	;.db $00,$00,$00,$00,$00,$00,$00,$00,$1A,$1C,$0F,$1D,$1D,$00,$0B,$00 
	;.db $1E,$19,$00,$1D,$1E,$0B,$1C,$1E,$00,$00,$00,$00,$00,$00,$00,$00 ; Press A to Start
	.org $E2e0
	.db $25,$26,$29,$2A,$27,$28,$25,$29,$2A,$26,$25,$25,$27,$2A,$28,$29
	.db $2A,$26,$25,$27,$2A,$29,$26,$25,$27,$28,$2A,$26,$27,$25,$2A,$27 ; 땅
	
	.org $E4C0
  
palette:
	.db $30,$30,$00,$30, $30,$30,$00,$30, $30,$30,$00,$30, $30,$30,$00,$30  ; 배경 팔레트
	.db $30,$30,$00,$30, $30,$30,$00,$30, $30,$30,$00,$30, $30,$30,$00,$30  ; 스프라이트 팔레트
  
trexHeadA:
	.db $00, $00, $00, $10   ;y, tilenum, set, x
	.db $00, $01, $00, $18   ;y, tilenum, set, x
	.db $00, $02, $00, $20   ;y, tilenum, set, x
  
	.db $08, $03, $00, $00   ;y, tilenum, set, x
	.db $08, $04, $00, $10   ;y, tilenum, set, x
	.db $08, $05, $00, $18   ;y, tilenum, set, x
	.db $08, $06, $00, $20   ;y, tilenum, set, x
trexHeadB:
	.db $00, $16, $00, $10   ;y, tilenum, set, x
	.db $00, $17, $00, $18   ;y, tilenum, set, x
	.db $00, $18, $00, $20   ;y, tilenum, set, x
  
	.db $08, $03, $00, $00   ;y, tilenum, set, x
	.db $08, $19, $00, $10   ;y, tilenum, set, x
	.db $08, $1a, $00, $18   ;y, tilenum, set, x
	.db $08, $1b, $00, $20   ;y, tilenum, set, x

trexBody:	
	.db $10, $07, $00, $00   ;y, tilenum, set, x
	.db $10, $08, $00, $08   ;y, tilenum, set, x
	.db $10, $09, $00, $10   ;y, tilenum, set, x
	.db $10, $0a, $00, $18   ;y, tilenum, set, x
	
	.db $18, $0b, $00, $00   ;y, tilenum, set, x
	.db $18, $0c, $00, $08   ;y, tilenum, set, x
	.db $18, $0d, $00, $10   ;y, tilenum, set, x
	.db $18, $0e, $00, $18   ;y, tilenum, set, x
	
trexLeg:
	.db $20, $0f, $00, $00   ;y, tilenum, set, x
	.db $20, $10, $00, $08   ;y, tilenum, set, x
	.db $20, $11, $00, $10   ;y, tilenum, set, x
	
	.db $28, $12, $00, $08   ;y, tilenum, set, x
	.db $28, $13, $00, $10   ;y, tilenum, set, x
trexLegA:
	.db $20, $0f, $00, $00   ;y, tilenum, set, x
	.db $20, $10, $00, $08   ;y, tilenum, set, x
	.db $20, $14, $00, $10   ;y, tilenum, set, x
	
	.db $28, $12, $00, $08   ;y, tilenum, set, x
	.db $28, $12, $00, $08   ;y, tilenum, set, x
trexLegB:
	.db $20, $0f, $00, $00   ;y, tilenum, set, x
	.db $20, $15, $00, $08   ;y, tilenum, set, x
	.db $20, $11, $00, $10   ;y, tilenum, set, x
	
	.db $28, $13, $00, $10   ;y, tilenum, set, x
	.db $28, $13, $00, $10   ;y, tilenum, set, x

cactusA:
	.db $00, $1C, $00, $08   ;y, tilenum, set, x
	
	.db $08, $1D, $00, $00   ;y, tilenum, set, x
	.db $08, $1E, $00, $08   ;y, tilenum, set, x
	.db $08, $1F, $00, $10   ;y, tilenum, set, x
	
	.db $10, $20, $00, $00   ;y, tilenum, set, x
	.db $10, $21, $00, $08   ;y, tilenum, set, x
	.db $10, $22, $00, $10   ;y, tilenum, set, x
	
	.db $18, $23, $00, $00   ;y, tilenum, set, x
	.db $18, $24, $00, $08   ;y, tilenum, set, x
	.db $18, $25, $00, $10   ;y, tilenum, set, x
	
	.db $20, $26, $00, $08   ;y, tilenum, set, x
	
	.db $28, $27, $00, $00   ;y, tilenum, set, x
	.db $28, $28, $00, $08   ;y, tilenum, set, x
	.db $28, $29, $00, $10   ;y, tilenum, set, x
  
	; 인터럽트 벡터
	.org $FFFA
	.dw NMI
	.dw RESET
	.dw 0
  
;;;;;;;;;;;;;;  
	.bank 2
	.org $0000
	.incbin "t-rex.chr"