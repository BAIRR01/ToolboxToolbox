classdef TbDockerStrategy < TbToolboxStrategy
    % Use Docker to pull down an image before use.
    %
    % 2016 benjamin.heasly@gmail.com
    
    methods
        function isPresent = checkIfPresent(obj, record, toolboxRoot, toolboxPath)
            % ask the docker daemon if the image is present
            if isempty(record.flavor)
                command = ['docker images --quiet ' record.url];
            else
                command = ['docker images ' record.url ' | grep ' record.flavor];
            end
            [status, result] = tbSystem(command);
            isPresent = status == 0 && ~isempty(result);
        end
        
        function [command, status, message] = obtain(obj, record, toolboxRoot, toolboxPath)
            
            try                
                if isempty(record.flavor)
                    command = ['docker pull ' record.url];
                else
                    command = ['docker pull ' record.url ':' record.flavor];
                end
               
                tbCheckInternet('asAssertion', true);
                [status, result] = tbSystem(command);
                if 0 ~= status
                    error('Docker pull failed: %s', result);
                end
                
            catch err
                status = -1;
                message = err.message;
                return;
            end
            
            % great!
            status = 0;
            message = 'docker pull OK';
        end
        
        function [command, status, message] = update(obj, record, toolboxRoot, toolboxPath)
            % just keep obtaining.  Use record.neverUpdate to prevent this.
            [command, status, message] = obj.obtain(record, toolboxRoot, toolboxPath);
        end
    end
end
