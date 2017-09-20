function [poly,poly_idx,opendat,boudat] = extract_boundary(v_start,v_end,bnde,pts,order,opendat,boudat)
% DESCRIPTION: Given a set of boundary edges and a starting and ending index 
%              of a singly- or multi-polygonal region, organize them in a 
%              winding order and/or add them to an existing opendat/boudat
%              structure.
%
% INPUTS:
%      v_start: the starting index of the boundary you want to trace
%        v_end: the ending index of the boundary you want to trace.
%         bnde: the indices of each boundary edge as a nbnde x 2 matrix
%         pts:  the x,y locations of all the points in the region
%               stored as an np x 2 matrix.
%         order:the order in which the traversal takes place
%               counter-clockwise (0) or clockwise (1).

% OUTPUTS:
%          poly: the boundary of each enclosing polygon sorted in winding-order
%                poly is returned as a cell-array of length number of polys.
%      poly_idx: indices of the polygon coordinates in the same format as
%                poly
%
% kjr,UND,CHL,2017
%
%                                           TRAVERSAL METHOD
% Pick any unvisited edge segment [v_start,v_next] and add these vertices to the polygon loop.
% Find the unvisited edge segment [v_i,v_j] that has either v_i = v_next or v_j = v_next and add the other vertex (the one not equal to v_next) to the polygon loop.
% Reset v_next as this newly added vertex, mark the edge as visited and continue from 2.
% Traversal is done when we get back to v_start.
% NOTE: that the signed area will be positive if the vertices are
% oriented counterclockwise, and will be negative if it is oriented clockwise
bnde= unique(bnde,'rows');
active = true(size(bnde,1),1);
p = 0;

p = p + 1;
[rt,dmy] = find(v_start==bnde);
r  = rt(1); 
tsel = bnde(r,:); 
sel  = tsel(tsel~=v_start);
v_next = sel; 
active(r) = 0;

temp  = pts(bnde(r,:)',:);
temp2 = bnde(r,:)';
k = 2;
while v_next~=v_end % terminates when we reach v_end
    rt= (v_next==bnde(:,1) | v_next==bnde(:,2)) &  active;
    %r = cumsum(rt,1)==1 & rt;
    r = find(rt,1);
    tsel = bnde(r,:); 
    sel=tsel(tsel~=v_next);
    k = k + 1;
    temp(k,:)= pts(sel,:);
    temp2(k,:)= sel;
    active(r) = 0;
    v_next = sel;
    % exhausted all edges and couldn't connect
    if(~any(active)), break, end
end
poly{p}     = temp;
poly_idx{p} = temp2;
[area]=parea(poly{p}(:,1),poly{p}(:,2));
if(order==0) % ccw
    if sign(area)<0
        poly{p} = flipud(poly{p});
        poly_idx{p} = flipud(poly_idx{p});
    end
else % cw
    if sign(area)>0
        poly{p} = flipud(poly{p});
        poly_idx{p} = flipud(poly_idx{p});
    end
end
figure; 
plot(pts(bnde(:),1),pts(bnde(:),2),'k.'); hold on; 
plot(poly{1}(:,1),poly{1}(:,2),'r-','linewi',2); 
type = input('What kind of boundary is this, 1 (land) or 2 (ocean)?'); 
if(~isempty(opendat) || ~isempty(boudat))
    if(type==1)
        
        nbou = boudat.nbou;
        nvel = boudat.nvel;
        nvell= boudat.nvell;
        nbvv = boudat.nbvv;
        ibtype = boudat.ibtype;
        
        nbou = nbou + 1;
        nvell(nbou) = length(poly{1}(:,1));
        nvel = nvel + nvell(nbou);
        nbvv(1:nvell(nbou),nbou) = poly_idx{1}(:);
        ibtype(nbou) = 20;
        
        boudat.nbou = nbou ;
        boudat.nvel = nvel ;
        boudat.nvell = nvell ;
        boudat.ibtype = ibtype ;
        boudat.nbvv = nbvv ;
        
    elseif(type==2)
        nope = opendat.nope;
        nvdll= opendat.nvdll;
        neta = opendat.neta;
        ibtype=opendat.ibtypee;
        nbdv  = opendat.nbdv;
        
        nope = nope + 1;
        nvdll(nope) = length(poly_idx{1}(:,1));
        neta = neta + nvdll(nope);
        ibtype(nope) = 0;
        nbdv(1:nvdll(nope),nope) = poly_idx{1}(:,1);
        
        % ocean boundary
        opendat.nope = nope ;
        opendat.neta = neta ;
        opendat.nvdll = nvdll ;
        opendat.ibtype = ibtype ;
        opendat.nbdv = nbdv ;
        
    else
        disp('Wrong input: must be either 1 or 2');
    end
end

end
% helper function, computes area of polygon
function [area]=parea(x,y)
n    = length(x);
xp   = [x; x(1)];
yp   = [y; y(1)];
area = 0;
for i = 1:n
    area = area + det([xp(i), xp(i+1); yp(i), yp(i+1)]);
end
area = 1/2*area;
end