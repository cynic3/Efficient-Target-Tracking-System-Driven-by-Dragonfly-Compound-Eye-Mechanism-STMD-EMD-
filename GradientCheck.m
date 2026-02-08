function tau_FA=GradientCheck(current_frame, previous_frame)
[m,n]=size(current_frame);
tau_FA=zeros(m,n);
for i=1:m
    for j=1:n
        if current_frame(m,n)>previous_frame(m,n)
            tau_FA(i,j)=3;
        else 
            tau_FA(i,j)=70;
        end
    end
end