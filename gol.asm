assume ds:data,ss:stack,cs:code
;game of life created by po in 2018/1/8
data segment
	sharedVar db 1						;这个是一个共享的数据 如果按下了enter 就改变为1  按下esc  就改变为0
	cursorpos db 5,6
	;matrix db 40 dup (1),40 dup (0),23*80 dup (0) 
	matrix db 24*80 dup (0)
	matrixstate db 24*80 dup(0)
	operation db 'directionarrow   Mark   Row   Rolumn   exit','$'
data ends

stack segment

stack ends

code segment					;在timer里面需要scan一遍 获得matrix的状态机数据 在根据数据来进行原矩阵的变化 cleanScreen showmartix
start:

	mov al,34h   ; 设控制字值   
	out 43h,al   ; 写控制字到控制字寄存器   
	mov ax,0ffffh ; 中断时间设置  
	out 40h,al   ; 写计数器 0 的低字节   
	mov al,ah    ; AL=AH   
	out 40h,al   ; 写计数器 0 的高字节   
  
  
    xor ax,ax           ; AX = 0  
    mov ds,ax           ; DS = 0  
    mov word ptr ds:[20h],offset Timer  ; 设置时钟中断向量的偏移地址  
    mov ax,cs   
    mov word ptr ds:[22h],ax        ; 设置时钟中断向量的段地址=CS  

	

	mov ax,data					;字段初始化
	mov ds,ax
	mov ax,stack
	mov ss,ax

	
	call clearScreen                                                                  
	;call initView
	call show_operation
	call showCursor
	
	again:
		;call clearScreen
		mov ah,01				;没有按键按下返回again
		int 16h
		je again
		;call clearScreen
		mov ah,0h
		int 16h
		
		cmp ah,72				;ah是扫描码 al是asc码
		je up
		
		cmp ah,75
		je left
		
		cmp ah,77
		je right
		
		cmp ah,80
		je down
		
		cmp ah,50
		je mark
		
		cmp ah,19
		je row
		
		cmp ah,46
		je column
		
		jmp again
		
		
		up:
		sub byte ptr ds:[cursorpos],1
		call showCursor
		jmp again
		
		left:
		sub byte ptr ds:[cursorpos+1],1
		call showCursor
		jmp again
		
		right:
		add byte ptr ds:[cursorpos+1],1
		call showCursor
		jmp again
		
		down:
		add byte ptr ds:[cursorpos],1
		call showCursor
		jmp again
		
		mark:
		mov al,ds:[cursorpos]
		call calLine
		mov si,ax
		mov al,ds:[cursorpos+1]
		mov ah,0
		add si,ax
		mov ds:[matrix+si],1
		call showMatrix
		jmp again
		
		row:
		mov al,ds:[cursorpos]
		call calLine						;ax为基址
		mov cx,80
		mov si,ax
		lop2:
			mov [matrix+si],1
			inc si
		loop lop2
		call showMatrix
		jmp again
		
		column:
		mov al,ds:[cursorpos+1]
		mov ah,0
		mov si,ax
		mov cx,24
		lop3:
			mov [matrix+si],1
			add si,80
		loop lop3
		call showMatrix
		jmp again
	;call showMatrix
	
	mov ax,4c00H
	int 21h
	
Timer:
	cmp [sharedVar],0
	je continue1
	call generateState
	call updateMatrix
	
	continue1:
	mov ah,0h
	int 16h
		
	cmp ah,1CH
	je clickEnter
	
	cmp ah,01H
	je clickEsc
	
	jmp return
	
	clickEnter:
	mov ds:[sharedVar],1
	jmp return
	
	clickEsc:
	mov ds:[sharedVar],0
	jmp return
	
	
	return:
	iret
	
calLine proc				;al作为行数 80放入ah  mul ah 结果存在ax 中
	mov ah,80
	mul ah
	ret
calLine endp
	
showCursor proc
	mov ah,2
	mov bh,0
	mov dh,ds:[cursorpos]	;dh为行数
	mov dl,ds:[cursorpos+1] ;dl为列数
	int 10h
	ret
showCursor endp

showMatrix proc
	mov ax,0B800H
	mov es,ax
	mov di,0
	mov si,0
	mov cx,24*80
	lop1:
		mov al,ds:[matrix+si]
		mov es:[di],al
		cmp al,1
		jne continue
		add byte ptr es:[di],2FH
		continue:
		inc di
		mov byte ptr es:[di],07h
		inc di
		inc si
	loop lop1
	ret
showMatrix endp

clearScreen proc
	mov ah,6
	mov al,0
	mov ch,0
	mov cl,0
	mov dh,25
	mov dl,80
	mov bh,07H
	int 10H
	ret
clearScreen endp

show_operation proc						;展示底部的提示菜单
	push ax	
	push bx
	push dx
	mov bh,0
	mov ah,02h
	mov dh,24
	mov dl,18
	int 10h
	mov ah,09h
	mov dx,offset operation
	int 21h
	mov ah,02h
	mov dh,24
	mov dl,35
	int 10h
	mov al,'M'
	call show_character
	mov ah,02h
	mov dh,24
	mov dl,42
	int 10h
	mov al,'R'
	call show_character
	mov ah,02h
	mov dh,24
	mov dl,48
	int 10h
	mov al,'C'
	call show_character
	mov ah,02h
	mov dh,24
	mov dl,57
	int 10h
	mov al,'E'
	call show_character
	pop dx
	pop bx
	pop ax
	ret
show_operation endp

show_character proc										;变色函数
	push ax
	push bx
	push cx
	mov ah,09h
	mov cx,1
	mov bl,04h
	int 10h
	pop cx
	pop bx
	pop ax
	ret
show_character endp

generateState proc										;生成四种状态中的一种,si是行 di 是列
	mov ch,0
	lopOut:
		mov cl,0
		lopInside:
			cmp ch,0
			je setZero
			
			cmp ch,23
			je setZero
			
			cmp cl,0
			je setZero
			
			cmp cl,79
			je setZero
			jmp notSetZero
			
			
			setZero:						;ch为行数
			mov al,ch
			call calLine
			push cx
			mov ch,0
			add ax,cx
			pop cx
			jmp jmpOutInLoop
			
			notSetZero:
			mov al,ch
			mov ah,cl
			call judge						;judge不能破坏cx al作为行数 ah作为列数 判断这个点属于的情况
			
			jmpOutInLoop:
			inc cl
			cmp cl,80
			jne lopInside
	inc ch
	cmp ch,24
	jne lopOut
	
	ret
generateState endp

updateMatrix proc										;state是0或者1 在matrix为0 2和3在matrix为1 这个很简单
	ret
updateMatrix endp

judge proc
	mov dl,al
	mov dh,0
	call calLine										;ax是偏移的基质
	mov bx,ax
	add bx,dx
	cmp [matrix+bx],1
	je liveCondition
	
	deathCondition:
	mov si,0
	add si,[matrix+bx-81]
	add si,[matrix+bx-80]
	add si,[matrix+bx-79]
	add si,[matrix+bx-1]
	add si,[matrix+bx+1]
	add si,[matrix+bx+79]
	add si,[matrix+bx+80]
	add si,[matrix+bx+81]
	cmp si,3
	je setOne
	mov [matrixstate+bx],0
	jmp return1
	
	setOne:
	mov [matrixstate+bx],1
	jmp return1
	
	
	liveCondition:
	
	retrun1:
	ret
judge endp

code ends
end start