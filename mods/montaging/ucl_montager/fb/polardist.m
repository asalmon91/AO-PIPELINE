function d = polardist(tr1, tr2)

t1 = tr1(:,1);
t2 = tr2(:,1);
r1 = tr1(:,2);
r2 = tr2(:,2);

d = sqrt(r1.^2 + r2.^2 - 2.*r1.*r2 .* cos(t2 - t1));

end
