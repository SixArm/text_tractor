require 'spec_helper'

describe Copycat::Users do
  it { should_not be_nil }

  specify { Copycat::Users.should respond_to(:create) }
  describe "creating a new user" do
    before(:each) do
      Copycat::Users.create(username: "test", password: "example", name: "Test User", superuser: true)
    end
    
    it "adds the user's details to Redis" do
      JSON.parse(Copycat.redis.get("users:test")).should == {
        "username" => "test",
        "name" => "Test User",
        "superuser" => true
      }
    end
    
    it "adds the user's username to the list of users" do
      Copycat.redis.sismember("users", "test").should be_true
    end

    it "adds the user's hash for authentication" do
      Copycat.redis.sismember("user_hashes", Copycat::Users.hash_user("test", "example")).should be_true
    end

    it "defaults superuser to false" do
      Copycat::Users.create(username: "foo", password: "example", name: "Test User")
      JSON.parse(Copycat.redis.get("users:foo")).should == {
        "username" => "foo",
        "name" => "Test User",
        "superuser" => false
      }
    end

    it "raises an Users::DuplicateUserError if the username is already in use" do
      lambda { Copycat::Users.create(username: "test", password: "example", name: "Test User") }.should raise_error(Copycat::Users::DuplicateUserError)
    end
  end

  specify { Copycat::Users.should respond_to(:all) }
  describe "getting the full list of users" do
    before(:each) do
      @user1 = Copycat::Users.create(username: "test", password: "example", name: "Test User", superuser: false)
      @user2 = Copycat::Users.create(username: "jon", password: "test", name: "Jon Wood", superuser: true)
    end
    
    subject { Copycat::Users.all }

    it "includes all the users" do
      subject.should have(2).users
    end

    it "doesn't include the password for a user" do
      subject.first.should_not have_key("password")
    end

    it "includes all other details" do
      subject.should == [
        { "username" => "jon", "name" => "Jon Wood", "superuser" => true },
        { "username" => "test", "name" => "Test User", "superuser" => false },
      ]
    end

    it "sorts users alphabetically by their name" do
      subject.first["name"].should eq "Jon Wood"
      subject.last["name"].should eq "Test User"
    end
  end

  specify { Copycat::Users.should respond_to(:authenticate) }
  describe "authenticating a user" do
    before(:each) do
      Copycat::Users.create(username: "test", password: "example", name: "Test User")
    end

    it "returns true if the user and password match" do
      Copycat::Users.authenticate("test", "example").should be_true
    end

    it "returns false if only the user matches" do
      Copycat::Users.authenticate("test", "wrong").should be_false
    end

    it "returns false if only the password matches" do
      Copycat::Users.authenticate("wrong", "example").should be_false
    end

    it "returns false if neither attributes match" do
      Copycat::Users.authenticate("wrong", "wrong").should be_false
    end
  end

  specify { Copycat::Users.should respond_to(:get) }
  describe "loading a user" do
    before(:each) do
      Copycat::Users.create(username: "test", password: "example", name: "Test User")
    end

    it "returns the user's details if they exist" do
      Copycat::Users.get("test").should == {
        "username" => "test",
        "name" => "Test User",
        "superuser" => false
      }
    end

    it "returns nil if they do not exist" do
      Copycat::Users.get("bob").should be_nil
    end
  end

  specify { Copycat::Users.should respond_to(:exists?) }
  describe "checking the existance of a user" do
    before(:each) do
      Copycat::Users.create(username: "test", password: "example", name: "Test User")
    end
    
    specify { Copycat::Users.exists?("test").should be_true }
    specify { Copycat::Users.exists?("other").should be_false }
  end
end
