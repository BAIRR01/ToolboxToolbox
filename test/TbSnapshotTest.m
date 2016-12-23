classdef TbSnapshotTest < matlab.unittest.TestCase
    % Test the ToolboxToolbox deployment snapshots
    %
    % The Toolbox Toolbox should be able to detect versions/flavors for the
    % system and deployed toolboxes, and write new configurations that
    % includes the versions/flavors.
    %
    % 2016 benjamin.heasly@gmail.com
    
    properties
        testRepoUrl = 'https://github.com/ToolboxHub/sample-repo.git';
        toolboxRoot = fullfile(tempdir(), 'toolboxes');
        originalMatlabPath;
    end
    
    methods (TestMethodSetup)
        function saveOriginalMatlabState(obj)
            obj.originalMatlabPath = path();
            tbResetMatlabPath('full');
        end
        
        function cleanUpTempFiles(obj)
            if 7 == exist(obj.toolboxRoot, 'dir')
                rmdir(obj.toolboxRoot, 's');
            end
        end
    end
    
    methods (TestMethodTeardown)
        function restoreOriginalMatlabState(obj)
            path(obj.originalMatlabPath);
        end
    end
    
    methods (Test)
        function testReadWriteSystemInfo(obj)
            % deploy and make a snapshot
            config = tbToolboxRecord( ...
                'name', 'simple', ...
                'url', obj.testRepoUrl, ...
                'type', 'git');
            originalResult = tbDeployToolboxes( ...
                'config', config, ...
                'toolboxRoot', obj.toolboxRoot);
            obj.assertEqual(originalResult.status, 0);
            snapshot = tbDeploymentSnapshot(originalResult, ...
                'toolboxRoot', obj.toolboxRoot);
            
            % snapshot should contain some system info at the end
            obj.assertNumElements(snapshot, 2);
            systemInfo = snapshot(2);
            obj.assertInstanceOf(systemInfo.extra, 'struct');
            obj.assertEqual(systemInfo.extra.matlab_version, version());
            
            % system info should survive a JSON read-write cycle
            snapshotPath = fullfile(obj.toolboxRoot, 'snapshot.json');
            tbWriteConfig(snapshot, 'configPath', snapshotPath);
            snapshotAgain = tbReadConfig('configPath', snapshotPath);
            
            % want to compare 
            %   obj.assertEqual(snapshotAgain, snapshot);
            % but get false negatives like
            %   Actual char:
            %     Empty matrix: 1-by-0
            %   Expected char:
            %     ''

            % reasonable but weaker test than what I want above :-(
            obj.assertNumElements(snapshotAgain, 2);
            systemInfoAgain = snapshotAgain(2);
            obj.assertEqual( ...
                systemInfoAgain.extra.matlab_version, ...
                systemInfo.extra.matlab_version);
        end
        
        function testGitHead(obj)
            % use repository head revision
            config = tbToolboxRecord( ...
                'name', 'simple', ...
                'url', obj.testRepoUrl, ...
                'type', 'git');
            obj.deployAndCheckFlavors(config);
        end
        
        function testGitCommit(obj)
            % use repository head revision
            config = tbToolboxRecord( ...
                'name', 'simple', ...
                'url', obj.testRepoUrl, ...
                'flavor', '4da2f4d4de07d8de7df763d77d2b2daa008425f4', ...
                'type', 'git');
            obj.deployAndCheckFlavors(config);
        end
        
        function testSvnHead(obj)
            % use repository head revision
            config = tbToolboxRecord( ...
                'name', 'simple', ...
                'url', obj.testRepoUrl, ...
                'subfolder', 'trunk', ...
                'type', 'svn');
            obj.deployAndCheckFlavors(config);
        end
        
        function testSvnRevision(obj)
            % use specific repository revision
            config = tbToolboxRecord( ...
                'name', 'simple', ...
                'url', obj.testRepoUrl, ...
                'flavor', '5', ...
                'subfolder', 'trunk', ...
                'type', 'svn');
            obj.deployAndCheckFlavors(config);
        end
    end
    
    methods
        function deployAndCheckFlavors(obj, config)
            % deploy normally
            originalResult = tbDeployToolboxes( ...
                'config', config, ...
                'toolboxRoot', obj.toolboxRoot);
            obj.assertEqual(originalResult.status, 0);
            
            % detect deployed version
            strategy = tbChooseStrategy(config);
            deployedFlavor = strategy.detectFlavor(originalResult, ...
                'toolboxRoot', obj.toolboxRoot);
            
            % if given, declared flavor should match detected flavor
            if ~isempty(config.flavor)
                obj.assertEqual(deployedFlavor, config.flavor);
            end
            
            % make a "snapshot" config
            snapshot = tbDeploymentSnapshot(originalResult, ...
                'toolboxRoot', obj.toolboxRoot);
            
            % snapshot version should match deployed version
            obj.assertEqual(snapshot(1).flavor, deployedFlavor);
            
            % redeploy from the snapshot
            snapshotResult = tbDeployToolboxes( ...
                'config', snapshot, ...
                'toolboxRoot', obj.toolboxRoot, ...
                'reset', 'full');
            obj.assertEqual(snapshotResult.status, 0);
            
            % detect redeployed version directly
            redeployedFlavor = strategy.detectFlavor(snapshotResult, ...
                'toolboxRoot', obj.toolboxRoot);
            
            % redeployed version should matchsnapshot version
            obj.assertEqual(redeployedFlavor, snapshot(1).flavor);
        end
    end
end
