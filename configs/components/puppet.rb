component "puppet" do |pkg, settings, platform|
  pkg.load_from_json("configs/components/puppet.json")

  pkg.build_requires "ruby-#{settings[:ruby_version]}"
  pkg.build_requires "facter"
  #pkg.build_requires "hiera"

  pkg.replaces 'forage-puppet', '4.0.0'
  pkg.provides 'forage-puppet', '4.0.0'

  pkg.apply_patch 'resources/patches/puppet/run_mode_settings.patch'
  pkg.apply_patch 'resources/patches/puppet/rehomed_basemodulepath.patch'
  pkg.apply_patch 'resources/patches/puppet/remove_hiera_dep.patch'

  # Puppet requires tar, otherwise PMT will not install modules
  if platform.is_solaris?
    if platform.os_version == "11"
      pkg.requires 'archiver/gnu-tar'
    end
  else
    # PMT doesn't work on AIX, don't add a useless dependency
    # We will need to revisit when we update PMT support
    pkg.requires 'tar' unless platform.is_aix?
  end

  if platform.is_windows?
    pkg.environment "FACTERDIR" => settings[:facter_root]
    pkg.environment "PATH" => "$$(cygpath -u #{settings[:gcc_bindir]}):$$(cygpath -u #{settings[:ruby_bindir]}):$$(cygpath -u #{settings[:bindir]}):/cygdrive/c/Windows/system32:/cygdrive/c/Windows:/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0"
    pkg.environment "RUBYLIB" => "#{settings[:hiera_libdir]};#{settings[:facter_root]}/lib"
  end

  if platform.is_windows?
    vardir = File.join(settings[:sysconfdir], 'puppet', 'cache')
    configdir = File.join(settings[:sysconfdir], 'puppet', 'etc')
    logdir = File.join(settings[:sysconfdir], 'puppet', 'var', 'log')
    piddir = File.join(settings[:sysconfdir], 'puppet', 'var', 'run')
    prereqs = "--check-prereqs"
  else
    vardir = File.join(settings[:prefix], 'cache')
    configdir = settings[:puppet_configdir]
    logdir = settings[:logdir]
    piddir = settings[:piddir]
    prereqs = "--no-check-prereqs"
  end
  pkg.install do
    [
      "#{settings[:host_ruby]} install.rb \
        --ruby=#{File.join(settings[:bindir], 'ruby')} \
        #{prereqs} \
        --bindir=#{settings[:bindir]} \
        --configdir=#{configdir} \
        --sitelibdir=#{settings[:ruby_vendordir]} \
        --codedir=#{settings[:puppet_codedir]} \
        --vardir=#{vardir} \
        --rundir=#{piddir} \
        --logdir=#{logdir} \
        --configs \
        --quick \
        --no-batch-files \
        --man \
        --mandir=#{settings[:mandir]}",
    ]
  end

  if !platform.is_windows?
    pkg.install do
      ["#{settings[:bindir]}/puppet module install puppetlabs-inventory --modulepath '/var/tmp/puppetlabs/opt/puppet/modules'"]
    end
  end

  if platform.is_windows?
    pkg.install do
      ["/usr/bin/tar -xvf ../inventory.tar",
       "/usr/bin/cp -R inventory #{settings[:prefix]}/modules/",
       "/usr/bin/cp #{settings[:prefix]}/VERSION #{settings[:install_root]}"]
    end
  end

  pkg.install_file ".gemspec", "#{settings[:gem_home]}/specifications/#{pkg.get_name}.gemspec"

  if platform.is_windows?
    # Install the appropriate .batch files to the INSTALLDIR/bin directory
    pkg.add_source("file://resources/files/windows/environment.bat", sum: "810195e5fe09ce1704d0f1bf818b2d9a")
    pkg.add_source("file://resources/files/windows/puppet.bat", sum: "002618e115db9fd9b42ec611e1ec70d2")
    pkg.add_source("file://resources/files/windows/puppet_interactive.bat", sum: "4b40eb0df91d2ca8209302062c4940c4")
    pkg.add_source("file://resources/files/windows/puppet_shell.bat", sum: "24477c6d2c0e7eec9899fb928204f1a0")
    pkg.add_source("file://resources/files/windows/run_puppet_interactive.bat", sum: "d4ae359425067336e97e4e3a200027d5")
    pkg.add_source("file://resources/files/inventory.tar")
    pkg.install_file "../environment.bat", "#{settings[:link_bindir]}/environment.bat"
    pkg.install_file "../puppet.bat", "#{settings[:link_bindir]}/puppet.bat"
    pkg.install_file "../puppet_interactive.bat", "#{settings[:link_bindir]}/puppet_interactive.bat"
    pkg.install_file "../run_puppet_interactive.bat", "#{settings[:link_bindir]}/run_puppet_interactive.bat"
    pkg.install_file "../puppet_shell.bat", "#{settings[:link_bindir]}/puppet_shell.bat"

    pkg.install_file "ext/windows/service/daemon.bat", "#{settings[:bindir]}/daemon.bat"
    pkg.install_file "ext/windows/service/daemon.rb", "#{settings[:service_dir]}/daemon.rb"
    pkg.install_file "../wix/icon/puppet.ico", "#{settings[:miscdir]}/puppet.ico"
    pkg.install_file "../wix/license/LICENSE.rtf", "#{settings[:miscdir]}/LICENSE.rtf"
    pkg.directory settings[:service_dir]
  end

  pkg.configfile File.join(configdir, 'puppet.conf')
  pkg.configfile File.join(configdir, 'auth.conf')

  pkg.directory vardir, mode: '0750'
  pkg.directory configdir
  pkg.directory settings[:puppet_codedir]
  pkg.directory File.join(settings[:puppet_codedir], "modules")
  pkg.directory File.join(settings[:prefix], "modules")
  pkg.directory File.join(settings[:puppet_codedir], 'environments')
  pkg.directory File.join(settings[:puppet_codedir], 'environments', 'production')
  pkg.directory File.join(settings[:puppet_codedir], 'environments', 'production', 'manifests')
  pkg.directory File.join(settings[:puppet_codedir], 'environments', 'production', 'modules')
  pkg.install_configfile 'conf/environment.conf', File.join(settings[:puppet_codedir], 'environments', 'production', 'environment.conf')

  if platform.is_windows?
    pkg.directory File.join(settings[:sysconfdir], 'puppet', 'var', 'log')
    pkg.directory File.join(settings[:sysconfdir], 'puppet', 'var', 'run')
  else
    pkg.directory File.join(settings[:logdir], 'puppet'), mode: "0750"
  end

  if platform.is_eos?
    pkg.link "#{settings[:sysconfdir]}", "#{settings[:link_sysconfdir]}"
  end
end
