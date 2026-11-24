#include <vendor/argparse/argparse.hpp>

#include <iostream>
#include <string>
#include <format>
#include <solver_anubis.h>

int main(int argc, char** argv){
    argparse::ArgumentParser program("RedPoW", "0.0.1");
    
    argparse::ArgumentParser anubis_command("anubis");
    anubis_command.add_description("Attack an anubis-protected web server");
    anubis_command.add_argument("url")
        .help("The URL of the webserver to attack");
    anubis_command.add_argument("-a", "--accelerated")
        .help("Use the GPU")
        .flag();

    argparse::ArgumentParser mCaptcha_command("mcaptcha");
    mCaptcha_command.add_description("Attack an  mCaptcha-protected HTML form");
    mCaptcha_command.add_argument("url")
        .help("The URL of the website the form is located on");
    mCaptcha_command.add_argument("-a", "--accelerated")
        .help("Use the GPU")
        .flag();

    program.add_subparser(anubis_command);
    program.add_subparser(mCaptcha_command);

    try {
        program.parse_args(argc, argv);
    } catch (const std::exception& err) {
        std::cerr << err.what() << std::endl;
        std::cerr << program;
        return 1;
    }

    std::string url =  program.get<std::string>("url");
    if (program.is_subcommand_used("anubis")) { 
        anubis::AnubisSolver anubisSolver(url);
        (void)anubisSolver.accessProtectedResource(program.get<bool>("--accelerated"));
    } else if (program.is_subcommand_used("mcaptcha")) {

    } else {
        std::cerr << "You must specify the type of service to attack" << std::endl;
    }

    return 0;
}
