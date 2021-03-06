classdef RampUpMotion < AirfoilMotion
    properties
        % does not depend on the airfoil
        % experimental parameters
        r % reduced pitch rate
        f_pts   
        alphadot %°/s
        
        % depends on the airfoil
        alpha_continuous_grow
        i_continuous_grow
        % experimental dynamic stall angles
        alpha_CConset
        alpha_CLonset
        % their indices
        i_CConset
        i_CLonset
        % model outputs
        alpha_lagonset % corresponds to alpha'_ds
        alpha_onset % modelled one
    end
    methods
        % convenient constructor with name/value pair of any attribute of RampUpMotion
        function obj = RampUpMotion(varargin)
            p = inputParser;
            % Add name / default value pairs
            mco = ?RampUpMotion;
            prop = mco.PropertyList; % makes a cell array of all properties of the specified ClassName
            for k=1:length(prop)
                if ~prop(k).Constant && ~prop(k).HasDefault
                    p.addParameter(prop(k).Name,[]);
                end
            end
            p.parse(varargin{:}); % {:} is added to take the content of the cells
            for k=1:length(prop)
                if ~prop(k).Constant && ~prop(k).HasDefault
                    obj.set(prop(k).Name,p.Results.(prop(k).Name))
                end
            end
            obj.fillProps() 
        end
        function isolateRamp(obj)
            dalpha = diff(obj.alpha);
            t_end = 5; % time during which the pitch angle must have stabilized to cutoff (must be above 10deg)
            i_end = find((abs(dalpha/obj.Ts)<1e-2) .* (obj.alpha(1:end-1)>10),ceil(t_end/obj.Ts)); 
            i_end = i_end(end);
            t_end = obj.t(i_end);
            fprintf('Data will be cutoff at %.2fs \n',t_end)
            obj.alpha = obj.alpha(1:i_end);
            obj.alpha_rad = obj.alpha_rad(1:i_end);
            if ~isempty(obj.analpha)
                obj.analpha = obj.analpha(1:i_end);
            end
            if ~isempty(obj.analpha_rad)
                obj.analpha_rad = obj.analpha_rad(1:i_end);
            else 
                obj.analpha_rad = deg2rad(obj.analpha_rad);
            end
            obj.t = obj.t(1:i_end);
            if ~isempty(obj.CN)
            obj.CN = obj.CN(1:i_end);
            end
            if ~isempty(obj.CC)
            obj.CC = obj.CC(1:i_end);
            end
            if ~isempty(obj.CL)
            obj.CL = obj.CL(1:i_end);
            end
            if ~isempty(obj.CD)
            obj.CD = obj.CD(1:i_end);
            end
            % then find valid values for continuously increasing alphas
            i_grow = findGrowingIndices(obj.alpha);
            for l=1:length(i_grow)
                ls(l) = length(i_grow{l});
            end
            [~,imax] = max(ls);
            obj.i_continuous_grow = i_grow{imax};
            obj.alpha_continuous_grow = obj.alpha(i_grow{imax});
        end
        function setAlphaDot(obj,alphadot)
            % sets alphadot in degrees
            dalphadt = diff(obj.alpha)./diff(obj.t);
            if nargin > 1
                obj.alphadot = alphadot; % deg/s
            elseif isempty(obj.alphadot)
                warning('Alphadot was computed as the maximum rate for this ramp.')
                obj.alphadot = max(dalphadt); % deg/s
            end
            if ~isempty(obj.alpha) 
                opts = optimset('Diagnostics','off','Display','off');
                analpha0 = lsqcurvefit(@(x,xdata) obj.alphadot*xdata+x,0,obj.t(dalphadt>=5),obj.alpha(dalphadt>=5),[],[],opts);
            else
                analpha0 = 0;
            end
            if isempty(obj.t)
                obj.t = linspace(0,round(35/obj.alphadot,1),500);
            end
            obj.analpha = obj.alphadot*obj.t + analpha0;
            t_start = - analpha0/obj.alphadot;
            % set angles before t0 = 0 
            obj.analpha(obj.analpha <=0 ) = 0;
            % set angles equal to 30 when motion is over
            t_end = 30/obj.alphadot + t_start;
            obj.analpha(obj.t >= t_end) = 30;
        end
        function setPitchRate(obj,airfoil)
            if isempty(obj.alphadot) || isempty(obj.analpha)
                obj.setAlphaDot();
            end
            obj.r = deg2rad(obj.alphadot)*airfoil.c/(2*obj.V);
            dalpha_rad = diff(obj.alpha_rad);
            dalpha_raddt = (dalpha_rad(2:end) + dalpha_rad(1:end-1))/(2*obj.Ts); % way smoother than Euler method (dalphadt = dalpha(1:end-1)/obj.Ts)!
            obj.rt = movmean(dalpha_raddt*airfoil.c/(2*obj.V),30);
            if isempty(obj.S)
                obj.S = 2*obj.V*obj.t/airfoil.c;
            end
        end
        function findExpOnset(obj)
            % finds experimental dynamic stall onset for a specific ramp-up
            % experiment. Is then used in Sheng algorithm to define the
            % vector alpha_ds.
%             obj.CNslope1 = lsqcurvefit(@(x,xdata) x*xdata,0,obj.alpha(obj.alpha<15),obj.CN(obj.alpha<15));
%             err = abs(obj.CN - obj.CNslope1*obj.alpha);
%             i_CNonset = find(err>1e-2);
%             [CNmax,iCNmax] = max(obj.CN);
            %obj.CNslope2 = lsqcurvefit(@(x,xdata) x*xdata+CNmax-x*xdata(iCNmax),0,obj.alpha(1:iCNmax),obj.CN(1:iCNmax));
            %             dCLdalpha = diff(obj.CL(obj.i_continuous_grow))./diff(obj.alpha_continuous_grow);
%             figure
%             plot(obj.alpha(1:length(dCLdalpha)),dCLdalpha)
%             hold on
%             xlabel('\alpha')
%             ylabel('dC_N/d\alpha')
%             grid on
            % onset based on CC curve
            
            % defines the location of the stop of the motion, to reject the
            % peak associated with added mass drop
            dalpha = diff(obj.alpha);
            if isempty(obj.S)
                error('Convective time has not been computed.')
            end
            i_stop = find(dalpha(obj.S(1:length(dalpha))>1)<1e-5,1)+find(obj.S>1,1);            
            [~,obj.i_CConset] = min(obj.CC);
            obj.alpha_CConset = obj.alpha(obj.i_CConset); % Sheng uses an inverted definition of CC
            [~,obj.i_CLonset] = max(obj.CL);
            obj.alpha_CLonset = obj.alpha(obj.i_CLonset);
            if (obj.S(i_stop) - obj.S(obj.i_CConset))<0.5
                warning('The maximum of CC for %s (r=%.3f) is close to the stop of the motion and therefore to the added mass loss. CC-based DS onset may be unreliable.',obj.name,obj.r)
            elseif (obj.S(i_stop) - obj.S(obj.i_CLonset))<0.5
                warning('The maximum of CL for %s (r=%.3f) is close to the stop of the motion and therefore to the added mass loss. CL-based DS onset may be unreliable.',obj.name,obj.r)
            end
            if strcmp(obj.name,'ms023mpt1')
               % do
            end
        end
        function findModelOnset(obj,airfoil)
            % finds the Sheng-predicted dynamic stall angle for a specific
            % time-evolution of alpha. Predicts alpha_onset from
            % alpha_lagonset from previously defined alpha_ds0.
            i_lagonset = find(obj.alpha_lag>airfoil.alpha_ds0,1);
            if isempty(i_lagonset)
                warning('The airfoil "%s" does not show stall in the experiment %s.',airfoil.name,obj.name)
            else
                if ~isempty(obj.alpha)
                obj.alpha_lagonset = obj.alpha(i_lagonset);
                obj.alpha_onset = interp1(obj.alpha_lag(obj.i_continuous_grow),obj.alpha_continuous_grow,obj.alpha_lagonset);
                elseif ~isempty(obj.analpha) % if alpha is empty
                obj.alpha_lagonset = obj.analpha(i_lagonset);
                [c,ia] = unique(obj.analpha_lag);
                obj.alpha_onset = interp1(c,obj.analpha(ia),obj.alpha_lagonset);
                else
                error('Impossible to define stall angle. %s has no angle of attack defined.',obj.name)
                end
            end
        end
        function computeAnalyticalImpulsiveLift(obj,TlKalpha)
            % analytical alphas, angles in rad
            dalpha = diff(obj.analpha);
            ddalpha = diff(dalpha);
            D = zeros(size(ddalpha));
            for n=2:length(ddalpha)
                D(n) = D(n-1)*exp(-obj.Ts/TlKalpha)+((dalpha(n)-dalpha(n-1))/obj.Ts)*exp(-obj.Ts/2*TlKalpha); % the second term is equal to zero if alphadot is constant
            end
            obj.CNI = 4*TlKalpha/obj.M*(obj.alphadot-D);
        end
        function computeAnalyticalCirculatoryLift(obj,airfoil)
            dt = mean(diff(obj.t));
            deltaalpha = obj.alphadot*dt*ones(size(obj.alpha)); % deg
            rule = 'mid-point';
            [X,Y] = obj.computeDuhamel(deltaalpha,rule);
            % effective angle of attack
            obj.alphaE = obj.analpha-X-Y;
            obj.alphaE_rad = deg2rad(obj.alphaE);
            obj.CNC = airfoil.steady.slope*obj.alphaE; % alpha is in degrees, slope is in 1/deg
            
        end
        function plotCL(obj,xaxis)
            figure
            if (~exist('xaxis','var') || strcmp(xaxis,'alpha'))
                plot(obj.alpha,obj.CL,'LineWidth',2,'DisplayName','C_L')
                hold on
                plot(obj.alpha_CLonset,max(obj.CL),'d','MarkerEdgeColor','k','MarkerFaceColor','k','C_{L,DS} C_L-based')
                xlabel('\alpha (°)')
            elseif strcmp(xaxis,'convectime')
                plot(obj.S,obj.CL,'LineWidth',2)
                hold on
                plot(obj.S(obj.i_CLonset),max(obj.CL),'d','MarkerEdgeColor','k','MarkerFaceColor','k','DisplayName','C_{L,DS} C_L-based')
                xlabel('t_c')
            end
            grid on
            ax = gca;
            ax.FontSize = 20;
            ylabel('C_L')
            legend('Location','SouthEast')
            title(sprintf('%s ($\\dot{\\alpha} = %.2f ^{\\circ}$/s)',obj.name,obj.alphadot),'interpreter','latex')
        end
        function plotCD(obj)
            figure
            plot(obj.S,obj.CD,'LineWidth',2)
            grid on
            xlabel('t_c')
            ylabel('C_D')
            title(sprintf('%s ($\\dot{\\alpha} = %.2f ^{\\circ}$/s)',obj.name,obj.alphadot),'interpreter','latex')
        end
        function plotCN(obj,mode)
            figure
            switch mode 
                case 'angle'
                    plot(obj.alpha,obj.CN,'DisplayName','C_N','LineWidth',3)
                    hold on 
                    plot(obj.alpha_CConset,obj.CN(obj.i_CConset),'diamond','MarkerFaceColor','black','MarkerEdgeColor','black','MarkerSize',15,'DisplayName','C_{N,ds} C_C-based')
                    xlabel('\alpha (°)')
                case 'convectime'
                    load('../CNcrit','CNcrit')
                    plot(obj.S,obj.CN,'DisplayName','C_N','LineWidth',3)
                    hold on
                    plot(obj.S(obj.i_CConset),obj.CN(obj.i_CConset),'d','MarkerFaceColor','black','MarkerEdgeColor','black','MarkerSize',15,'DisplayName','C_{N,ds} C_C-based')
                    yline(CNcrit,'Color','r','LineStyle','--','LineWidth',1,'DisplayName','C_{N,ds}^0')
                    xlabel('t_c')
                otherwise 
                    error('mode must be angle or convectime')
            end
            grid on
            legend('Location','SouthEast','FontSize',20)
            ax = gca; 
            ax.FontSize = 20; 
            ylabel('C_N')
            title(sprintf('%s ($\\dot{\\alpha} = %.2f ^{\\circ}$/s)',obj.name,obj.alphadot),'interpreter','latex')
        end
        function plotCNLag(obj)
            figure
            if ~isempty(obj.alpha_lag)
                plot(obj.alpha,obj.CN,'DisplayName','C_N(\alpha)')
                hold on
                plot(obj.alpha_lag,obj.CN,'--','DisplayName','C_N(\alpha'')')
            elseif ~isempty(obj.analpha_lag)
                plot(obj.analpha,obj.CN,'DisplayName','C_N(\alpha)')
                hold on
                plot(obj.analpha_lag,obj.CN,'--','DisplayName','C_N(\alpha'')')
                warning('%s : CN curve was displayed for analytical alpha as the experimental alpha was not defined.',obj.name)
            else 
                error('alpha_lag is not defined')
            end
            grid on
            legend('Location','SouthEast')
            xlabel('\alpha (°)')
            ylabel('C_N')
            title(obj.name)
        end
        function fig = plotCC(obj,mode)
            % we should also plot CLonset
            fig = figure('name',sprintf('r=%.3f',obj.r));
            switch mode
                case 'angle'
                    plot(obj.alpha,obj.CC,'LineWidth',3,'DisplayName','C_C')
                    hold on
                    plot(obj.alpha_CConset,min(obj.CC),'diamond','MarkerFaceColor','black','MarkerEdgeColor','black','MarkerSize',15,'DisplayName','\alpha_{ds,CC}')
                    xlabel('\alpha (°)')
                case 'convectime'
                    plot(obj.S,obj.CC,'LineWidth',3,'DisplayName','C_C')
                    hold on
                    plot(obj.S(obj.i_CConset),min(obj.CC),'diamond','MarkerFace','black','MarkerEdgeColor','black','MarkerSize',15,'DisplayName','\alpha_{ds,CC}')
                    xlabel('t_c')
            end
            grid on
            legend('Location','SouthEast','FontSize',20)
            ax = gca; 
            ax.FontSize = 20; 
            ylabel('C_C')
            title(sprintf('%s ($\\dot{\\alpha} = %.2f ^{\\circ}$/s)',obj.name,obj.alphadot),'interpreter','latex')
        end
        function plotAlpha(obj,mode)
            plotAlpha@AirfoilMotion(obj,mode)
            if ~isempty(obj.alpha_CConset) && strcmp(mode,'full')
                plot(obj.S(obj.i_CConset),obj.alpha_CConset,'diamond','MarkerFaceColor','k','MarkerEdgeColor','k','MarkerSize',15,'DisplayName','\alpha_{ds,CC}')
            end
            title(sprintf('%s ($\\dot{\\alpha}$ = %.2f $^o$/s)',obj.name,obj.alphadot),'interpreter','latex')            
        end
        function plotPitchRate(obj)
            figure
            plot(obj.t(1:length(obj.rt)),obj.rt,'DisplayName','r(t)')
            hold on
            plot(obj.t,obj.r*ones(size(obj.t)),'--','DisplayName','r')
            plot(obj.t(obj.i_CConset),obj.rt(obj.i_CConset),'rx')
            legend show
            xlabel('t (s)')
            ylabel('r (-)')
            grid on
        end
    end
end