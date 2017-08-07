function [ p , t ] = Fix_bad_edges_and_mesh( p , t, nscreen )
% [ p , t ] = Fix_bad_edges_and_mesh( p , t )
%   Detailed explanation goes here

% Ensure mesh is "fixed"
[p,t] = fixmesh(p,t);

% First delete unecessary elements outside main mesh (fast)
[p,t] = delete_elements_outside_main_mesh(p,t,nscreen);

% Second, delete unecessary elements inside main mesh (iterative; slow)
[p,t] = delete_elements_inside_main_mesh(p,t,nscreen);

if nscreen; disp('finished cleaning up mesh..'); end

% Fourth, delete bad remaining elements and move some nodes (fast)
%[p,t] = fix_interior_angles(p,t);

% Checking again 
%[p,t] = delete_elements_outside_main_mesh(p,t);
%[p,t] = delete_elements_inside_main_mesh(p,t);
%disp('finished cleaning and fixing mesh..')
end

function [p,t] = delete_elements_outside_main_mesh(p,t,nscreen)
%% Delete all elements outside the main mesh
t1 = t; t = []; L = length(t1);
while 1
    % Give a random element not outside main mesh
    EToS =  randi(length(t1),1);
    min_del = L;
    while 1
        % Get connectivity
        EToE = Connect2D(t1);

        % Traverse grid deleting elements outside
        ic = zeros(ceil(sqrt(length(t1))*2),1);
        ic0 = zeros(ceil(sqrt(length(t1))*2),1);
        nflag = zeros(length(t1),1);
        icc0 = 1;
        ic0(1) = EToS;
        % loop until convergence is read
        while 1
            icc = 0;
            for nn = 1:icc0
                i = ic0(nn);
                % Flag the current element as OK
                nflag(i) = 1;
                % Search neighbouring elements
                for nb = EToE(i,:)
                   if nflag(nb) == 0
                       icc = icc + 1;
                       ic(icc) = nb;
                       nflag(nb) = 1;
                   end
                end
            end
            if icc ~= 0 
                icc0 = icc;
                ic0(1:icc0) = ic(1:icc0);
            else
                break
            end
        end
        if nscreen
            disp(['deleting ' num2str(length(find(nflag == 0))) ...
                  ' elements outside main mesh'])
        end
        if length(find(nflag == 0))/length(t1) < 0.5 || ...
           length(find(nflag == 0)) == min_del     
            % choice of EToS OK 
            % (deleting less than half of the triangulation)
            break
        else
            min_del = min(min_del,length(find(nflag == 0)));
            EToS = find(nflag == 0); EToS = EToS(randi(length(EToS),1));
        end
    end
    % adding to the triangulation
    t = [t; t1(nflag == 1,:)];
    % deciding whether portion is small enough to exit loop or not
    if length(find(nflag == 0))/L < 0.01
        break
    else
        % making the subset triangulation
        t1 = t1(nflag == 0,:);
    end
end

% delete disjoint nodes
[p,t] = fixmesh(p,t);

end

function [p,t] = delete_elements_inside_main_mesh(p,t,nscreen)
%% Delete some elements so that we have no nodes 
%%  connected to more than 2 boundary edges
% loop until no longer exist
while 1
    % Get boundaries
    [etbv,vxe] = extdom_edges2( t, p ) ;
    if length(etbv) == length(vxe); break; end
    %
    % Get all nodes that are on edges
    nodes_on_edge = unique(etbv(:));
    %
    % Count how many edges a node appears in
    N = numel(nodes_on_edge);
    count = zeros(N,1);
    for k = 1:N
        count(k) = sum(etbv(:) == nodes_on_edge(k));
    end
    %
    [vtoe, nne] = VertToEle(t);
    %[ nne, vtoe ] = NodeConnect2D( t );
    % Get the nodes which appear more than twice and delete element connected
    % to this nodes where all nodes of element are on boundary edges
    del_elem_idx = [];
    for i = nodes_on_edge(count > 2)'
        con_elem = vtoe(1:nne(i),i);
        n = 0; del_elem = [];
        for elem = con_elem'
           I = find(etbv(:) == t(elem,1), 1);
           J = find(etbv(:) == t(elem,2), 1);
           K = find(etbv(:) == t(elem,3), 1);
           % all nodes on element are boundary edges
           if ~isempty(I) && ~isempty(J) && ~isempty(K)
               n = n + 1;
               del_elem(n) = elem;
           end
        end
        if n == 1
           del_elem_idx(end+1) = del_elem;
        elseif n > 1
           tq = gettrimeshquan( p, t(del_elem,:));
           [~,idx] = min(tq.qm);
           % delete shittiest element
           del_elem_idx(end+1) = del_elem(idx);
        else
           % no connected elements have all nodes on boundary edge so we
           % just pick a random shitty element to delete
           tq = gettrimeshquan( p, t(con_elem,:));
           [~,idx] = min(tq.qm);
           % delete shittiest element
           del_elem_idx(end+1) = con_elem(idx);
           %del_elem_idx(end+1:end+length(con_elem)) = con_elem';
        end
    end
    if nscreen
        disp(['deleting ' num2str(length(del_elem_idx)) ...
              ' elements inside main mesh'])
    end
    t(del_elem_idx,:) = [];
    
    % delete disjoint nodes
    [p,t] = fixmesh(p,t);
    
    % Delete elements outside to ensure covergence
    [p,t] = delete_elements_outside_main_mesh(p,t,nscreen);
end

end

% Legacy shit
% function [p,t] = fix_interior_angles(p,t)
% %% Identify bad elements and move one node to centre of surrounding ones
%     % First, delete elements with almost 180 degree angles
%     tq = gettrimeshquan( p, t);
%     tq.vang = real(tq.vang);
%     [I,~] = find(tq.vang > 175*pi/180);
%     disp(['deleting ' num2str(length(I)) ' extremely thin elements'])
%     % delete the element
%     t(I,:) = [];
%     % delete disjoint nodes
%     [p,t] = fixmesh(p,t);
%     
%     % Second, delete elements with larger than 150 degree angles and move
%     % point to mid point of existing corners
%     tq = gettrimeshquan( p, t);
%     tq.vang = real(tq.vang);
%     [I,J] = find(tq.vang > 150*pi/180);
%     for i = 1:length(I)
%         % get nodes of the element and the node corresonding to large
%         % angle and the center point of the other nodes
%         nodes = t(I(i),:);
%         node = nodes(J(i)); nodes(J(i)) = [];
%         center = mean(p(nodes,:));
%         % move the node inline with the other corners
%         p(node,:) = center; 
%     end
%     disp(['deleting ' num2str(length(I)) ...
%           ' very thin elements and moving nodes'])
%     % delete the element
%     t(I,:) = [];
%     % delete disjoint nodes
%     [p,t] = fixmesh(p,t);
%     
%     % Third, move nodes of elements with small or lightly large angles..
%     [ vtov, nnv ] = NodeConnect2D( t );
%     EToE = Connect2D(t);
%     tq = gettrimeshquan( p, t);
%     [I,~] = find(tq.vang < 30*pi/180 | tq.vang > 130*pi/180); 
%     disp(['moving nodes for ' num2str(length(I)) ' somewhat thin elements'])
%     %       
%     J = [];
%     for i = I'
%         if length(unique(EToE(i,:))) == 2
%             % Only connected to one other element 
%             %(we want to just delete this one)
%             J(end+1) = i;
%         else
%             % Get the node belonging to largest angle
%             [ang,j] = max(tq.vang(i,:));
%             if ang > 90*pi/180
%                 % Move >90 deg node to center of surrounding nodes
%                 node = t(i,j) ;
%                 center = mean(p(vtov(1:nnv(node),node),:));
%                 p(node,:) = center; 
%             end
%         end
%     end
%     disp(['deleting ' num2str(length(J)) ' somewhat thin elements'])
%     % delete those elements indicated
%     t(J,:) = [];
%     % delete disjoint nodes
%     [p,t] = fixmesh(p,t);
%     
%     % Fourth, move nodes of elements with small angles..
%     [ vtov, nnv ] = NodeConnect2D( t );
%     etbv = extdom_edges(t, p);
%     etbv = unique(etbv(:));
%     tq = gettrimeshquan( p, t);
%     [I,J] = find(tq.vang < 30*pi/180); 
%     nn = 0;
%     for i = 1:length(I)
%         node = t(I(i),J(i));
%         if isempty(find(node == etbv, 1))
%             % Only move those nodes that are not attached to boundary
%             nn = nn + 1;
%             center = mean(p(vtov(1:nnv(node),node),:));
%             p(node,:) = center; 
%         end
%     end 
%     disp(['moving nodes for ' num2str(nn) ' slighthy thin elements'])
% end