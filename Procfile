web: bundle exec rackup -Ilib -p $PORT
console: bundle exec pry --simple-prompt -Ilib -renv
worker: bundle exec rake multi_work[$WORKER_COUNT]
