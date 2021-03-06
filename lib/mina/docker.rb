def command_with_comment(code)
  comment code
  command code
end

set :docker_compose_file, 'docker-compose.yml'
set :docker_image, 'xxxxx'
set :docker_hub, 'xxxxxx'

namespace :docker do
  desc 'docker publish image to hub (1. build , 2. tag , 3. push)'
  task :publish, [:build_command] do |_t, args|
    invoke :'docker:build', args.build_command
    invoke :'docker:tag'
    invoke :'docker:push'
  end

  desc 'docker build image'
  task :build, [:command] do |_t, args|
    run(:local) do
      command_with_comment %(docker build -t #{fetch(:docker_image)}:#{ENV.fetch('IMAGE_VERSION', 'latest')} -t #{fetch(:docker_image)}:latest #{args.command} ./)
    end
  end

  desc 'docker tag image'
  task :tag do
    run(:local) do
      command_with_comment %(docker tag #{fetch(:docker_image)}:#{ENV.fetch('IMAGE_VERSION', 'latest')} #{fetch(:docker_hub)}#{fetch(:docker_image)}:#{ENV.fetch('IMAGE_VERSION', 'latest')})
    end
  end

  desc 'docker push image'
  task :push do
    run(:local) do
      command_with_comment %(docker push #{fetch(:docker_hub)}#{fetch(:docker_image)}:#{ENV.fetch('IMAGE_VERSION', 'latest')})
    end
  end

  desc 'docker push image'
  task :image, [:command] do |_t, args|
    command_with_comment %(docker image #{args.command})
  end
end

namespace :docker_compose do
  desc 'docker_compose pull images'
  task :pull do
    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} pull)
    end
  end

  desc 'docker_compose up'
  task :up do
    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} up -d)
    end
  end

  desc 'docker_compose down'
  task :down do
    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} down)
    end
  end

  desc 'docker_compose restart'
  task :restart do
    in_path(fetch(:deploy_to)) do
      invoke :'docker_compose:down'
      invoke :'docker_compose:up'
    end
  end

  desc 'docker_compose ps'
  task :ps do
    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} ps)
    end
  end

  desc 'docker_compose run'
  task :run, [:command] do |_t, args|
    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} run --rm -e RAILS_ENV=#{fetch(:rails_env)} app #{args.command})
    end
  end

  desc 'docker_compose run with an interactive'
  task :run_with_it, [:command] do |_t, args|
    set :execution_mode, :exec

    in_path(fetch(:deploy_to)) do
      command_with_comment %(docker-compose --file #{fetch(:docker_compose_file)} run --rm -e RAILS_ENV=#{fetch(:rails_env)} app #{args.command})
    end
  end

  desc 'docker_compose migrate'
  task :migrate do
    comment "Call migrate"

    invoke :'docker_compose:run', "bundle exec rake db:migrate"
  end

  desc 'docker_compose update_menus_and_permissions'
  task update_menus_and_permissions: :remote_environment do
    comment "Update menus and permissions"

    invoke :'docker_compose:run', "bundle exec rake roles_and_permissions:update_menus"
    invoke :'docker_compose:run', "bundle exec rake roles_and_permissions:update_permissions"
  end

  desc 'docker_compose Starts an interactive console.'
  task :console do
    comment "rails console"

    invoke :'docker_compose:run_with_it', "bundle exec rails c"
  end

  desc 'docker_compose setup'
  task :setup do
    run(:remote) do
      command_with_comment %(mkdir -p "#{fetch(:deploy_to)}/log/")
      command_with_comment %(mkdir -p "#{fetch(:deploy_to)}/config")
    end

    run(:local) do
      command_with_comment "scp #{fetch(:docker_compose_file)} #{fetch(:user)}@#{fetch(:domain)}:#{fetch(:deploy_to)}/#{fetch(:docker_compose_file)}"
    end
  end

  desc "Deploys the current version to the server."
  task :deploy do
    command_with_comment "export IMAGE_VERSION=#{ENV.fetch('IMAGE_VERSION', 'latest')}"

    invoke :'docker:image', 'prune -f'
    invoke :'docker_compose:pull'
    invoke :'docker_compose:migrate'
    invoke :'docker_compose:update_menus_and_permissions'
    invoke :'docker_compose:up'
  end
end
