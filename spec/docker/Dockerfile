# Since CircleCI 2.0 does not have direct access to file system (since docker is running over TCP), we
# need to create another container for running the tests.

# TODO: Decide how to get the results out of this container

FROM circleci/ruby:2.2

ADD . /app
RUN sudo chown -R circleci:circleci /app

CMD ["echo", "0"]

