bits 16

mov si, bx
mov dh, al
mov cl, 12
mov ch, -12
mov cx, 0
mov cx, 0
mov dx, 0
mov dx, 0
mov al, [bx + si]
mov bx, [bp + di]
mov dx, [bp + 0]
mov ah, [bx + si + 4]
mov al, [bx + si + 4999]
mov [bx + di], cx
mov [bp + si], cl
mov [bp + 0], ch
