classdef SteadyCurve < handle
    properties
        alpha
        alpha_rad
        CN
        CNinv
        CL
        alpha0 = 0; % alpha0 = alpha(CN=0)
        alpha_ss % denoted alpha_1 in Beddoes-Leishman
        f
        CNalpha % 1/deg
        slope % pre-stall slope in 1/deg
        slope_rad % pre-stall slope in 1/rad
        fexp
        % Kirchhoff 
        S1
        S2
    end
    methods
        % constructor
        function obj = SteadyCurve(alphaSteady,CNSteady,alpha_ss)
            obj.alpha = reshape(alphaSteady,[length(alphaSteady),1]);
            obj.alpha_rad = deg2rad(obj.alpha);
            obj.CN = reshape(CNSteady,[length(CNSteady),1]);            
            obj.CNalpha = diff(obj.CN)./diff(obj.alpha); % in 1/deg
            if nargin < 3
                obj.computeStallAngle()
            else
                obj.alpha_ss = alpha_ss;
            end
            obj.computeSlope()
            obj.setAlpha0()
            obj.fitKirchhoff()
            obj.computeSeparation()
        end
        function computeStallAngle(obj)
            % Static stall angle
            dalpha = diff(obj.alpha);
            ialphass = 1;
            while (ialphass==1 || dalpha(ialphass-1)<0.01)
                ialphass = find(obj.CNalpha(ialphass:end)<0,1)+ ialphass;
            end
            obj.alpha_ss = obj.alpha(ialphass);
        end
        function computeSlope(obj)
            % CN slope for attached flow. Should be around 2pi/beta
            % converted to degrees. 
            CNslopes = obj.CNalpha(obj.alpha<10); % 1/deg
            if isempty(CNslopes)
                % assume inviscid thin airfoil
                warning('The steady curve contains no angle of attack below 10 degrees. An inviscid thin airfoil is assumed to determine the pre-stall slope.')
                obj.slope_rad = 2*pi; %1/rad
                obj.slope = obj.slope_rad*pi/180; %1/deg
            else
                alphaslopes = obj.alpha(1:length(CNslopes)+1); % deg
                obj.slope = sum(diff(alphaslopes).*CNslopes)/sum(diff(alphaslopes)); % mean weighted by the distance between two successive alphas
                obj.slope_rad = obj.slope*180/pi;
            end
            obj.CNinv = obj.slope*obj.alpha;
        end
        function plotCN(obj)
            figure
            plot(obj.alpha,obj.CN)
            grid on
            xlabel('\alpha (°)')
            ylabel('C_N')
            axis([0 Inf 0 Inf])
        end
        function plotCL(obj)
            figure
            plot(obj.alpha,obj.CL)
            grid on
            xlabel('\alpha (°)')
            ylabel('C_L')
        end
        function fitKirchhoff(obj)
            % Defines parameters for inital conditions (which is a very
            % good guess of the optimal value)
            stall_slope_minus = obj.CNalpha(find(obj.alpha<obj.alpha_ss,1,'last'));
            stall_slope_plus = obj.CNalpha(find(obj.alpha>obj.alpha_ss,1,'first'));
            S10 = 0.3*deg2rad(obj.alpha_ss)/(2*sqrt(0.7))*(((1+sqrt(0.7))/2)^2-stall_slope_minus/obj.slope_rad).^(-1);
            S20 = 0.66*deg2rad(obj.alpha_ss)/(2*sqrt(0.7))*(((1+sqrt(0.7))/2)^2-stall_slope_plus/obj.slope_rad).^(-1);
            
            % Optimizes S1,S2 so that the normal coefficient modelled with seppoint and Kirchhoff 
            % equals the experimental static CN
            opts = optimset('Display','off'); % replace off by iter for max. details
            Kfunc = @(x,alpha) kirchhoff(obj,obj.alpha,x);
            [fitparams,res,~,exitflag] = lsqcurvefit(Kfunc,[S10 S20],obj.alpha,obj.CN,[0 0],[10 10],opts);
            
            % Displays a message and assigns optimal params depending on
            % the solutation flag
            switch(exitflag)
                case 1
                    disp('lsqcurvefit converged to a solution.')
                    obj.S1 = fitparams(1);
                    obj.S2 = fitparams(2);
                    sprintf('Norm of the residual is %0.2e',res)
                case 2
                    disp('Change in X too small.')
                case 3
                    disp('Change in RESNORM too small.')
                    obj.S1 = fitparams(1);
                    obj.S2 = fitparams(2);
                    sprintf('Norm of the residual is %0.2e',res)
                case 4
                    disp('Computed search direction too small.')
                    warning('S1 and S2 have not been assigned, as lsqcurvefit has not converged to a solution')
                case 0
                    disp('Too many function evaluations or iterations.')
                    warning('S1 and S2 have not been assigned, as lsqcurvefit has not converged to a solution')
                case -1
                    disp('Stopped by output/plot function.')
                    warning('S1 and S2 have not been assigned, as lsqcurvefit has not conevrged to a solution')
                case -2
                    disp('Bounds are inconsistent.')
                    warning('S1 and S2 have not been assigned, as lsqcurvefit has not conevrged to a solution')
            end
        end          
        function plotKirchhoff(obj)
            figure
            plot(obj.alpha,obj.CN,'DisplayName','exp')
            hold on 
            plot(obj.alpha,obj.CNinv,'DisplayName','inviscid')
            if isempty(obj.S1)
                warning('Kirchhoff has not yet been fitted to this SteadyCurve .')
            else
                plot(obj.alpha,kirchhoff(obj,obj.alpha),'DisplayName','Kirchhoff model')
            end
            grid on
            legend('Location','SouthEast')
            xlabel('\alpha (°)')
            ylabel('C_N')
        end
        function setAlpha0(obj,alpha0)
            if nargin == 2
                if isnan(alpha0)
                    error('alpha0 cannot be NaN.')
                else
                    obj.alpha0 = alpha0;
                end
            elseif nargin == 1
                obj.alpha0 = interp1(obj.CN,obj.alpha,0,'linear','extrap');
            end
            fprintf('alpha0 is equal to %.4f \n',obj.alpha0)
        end
        function computeSeparation(obj)
            obj.f = seppoint(obj,obj.alpha); 
            if size(obj.alpha) == size(obj.CN)
                [~,imax] = max(size(obj.CN));
                if imax == 2
                    obj.alpha = reshape(obj.alpha,[length(obj.alpha), 1]);
                    obj.CN = reshape(obj.CN,[length(obj.CN), 1]);
                end
            else
                error('alpha and CN vectors must have the same orientation.')
            end
            % computes the experimental separation point using inverted Kirchhof model,
            % ref: Leishman, Principles of Helicopter Aerodynamics 2nd Ed., eq. 7.106 page 405
            unbounded_fexp = (2*sqrt(obj.CN./(obj.slope*(obj.alpha - obj.alpha0)))-1).^2;
            obj.fexp = max([zeros(size(obj.CN)),min([ones(size(obj.CN)), unbounded_fexp],[],2)],[],2);
            disp('fexp = ')
            disp(obj.fexp)
            disp('CN = ')
            disp(obj.CN)
        end
        function plotSeparation(obj)
            if isempty(obj.fexp)
                obj.computeSeparation()
            end
            figure
            plot(obj.alpha,obj.fexp,'DisplayName','f_{exp}')
            hold on 
            plot(obj.alpha,obj.f,'DisplayName','f')          
            grid on 
            xlabel('\alpha (°)')
            ylabel('x/c (-)')
        end
        function plotViscousRatio(obj)
            figure
            % must be f here because fexp is computed by inverted Kirchhoff
            % model
            plot(obj.f,obj.CN./obj.CNinv,'LineWidth',1,'DisplayName','visc. ratio')
            axis([0 1 0 1])
            grid on
            xlabel('f (x/c)')
            ylabel('\kappa (-)')
        end     
    end
end